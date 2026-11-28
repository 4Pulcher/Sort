def scan_raw(path, carve_max: int = _RAW_CARVE_MAX):
    """Yield (offset, name, exts, size) for every magic hit in the stream."""
    pats = _raw_patterns()
    try:
        f = open(path, "rb", buffering=0)
        probe = open(path, "rb", buffering=0)
    except OSError as exc:
        print(f"RAW-SCAN: cannot open {path}: {exc}")
        return
    base = 0
    carry = b""
    total = 0
    next_allowed = 0
    try:
        while True:
            block = f.read(_RAW_BLOCK)
            if not block:
                break
            total += len(block)
            buf = carry + block if carry else block
            buf_base = base - len(carry)
            hits = []
            for off, name, exts, lit, rx in pats:
                if lit is not None:
                    start = 0
                    while True:
                        pos = buf.find(lit, start)
                        if pos == -1:
                            break
                        hit = buf_base + pos - off
                        if hit >= 0:
                            hits.append((hit, name, exts))
                        start = pos + 1
                else:
                    for m in rx.finditer(buf):
                        hit = buf_base + m.start() - off
                        if hit >= 0:
                            hits.append((hit, name, exts))
            hits.sort()
            for hit, name, exts in hits:
                if hit < next_allowed:
                    continue
                probe.seek(hit)
                head = probe.read(min(carve_max, _RAW_BLOCK))
                size, exact = _raw_carve_size(head, name, carve_max)
                # an exact fragment owns its byte range; a capped guess only
                # suppresses hits at the very same offset
                next_allowed = (hit + size) if exact else (hit + 1)
                yield hit, name, exts, size, exact
            base += len(block)
            carry = buf[-_RAW_CARRY:]
    finally:
        f.close()
        probe.close()
