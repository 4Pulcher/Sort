def scan_raw_range(path, lo, hi, carve_max=_RAW_CARVE_MAX):
    """Like scan_raw() but limited to absolute offsets [lo, hi)."""
    pats = _raw_patterns()
    try:
        f = open(path, "rb", buffering=0)
        probe = open(path, "rb", buffering=0)
    except OSError as exc:
        print(f"SCAN: cannot open {path}: {exc}")
        return
    base = 0
    carry = b""
    next_allowed = lo
    try:
        while base < hi:
            block = f.read(_RAW_BLOCK)
            if not block:
                break
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
                        if lo <= hit < hi:
                            hits.append((hit, name, exts))
                        start = pos + 1
                else:
                    for m in rx.finditer(buf):
                        hit = buf_base + m.start() - off
                        if lo <= hit < hi:
                            hits.append((hit, name, exts))
            hits.sort()
            for hit, name, exts in hits:
                if hit < next_allowed:
                    continue
                probe.seek(hit)
                head = probe.read(min(carve_max, _RAW_BLOCK))
                size, exact = _raw_carve_size(head, name, carve_max)
                next_allowed = (hit + size) if exact else (hit + 1)
                yield hit, name, exts, size, exact
            base += len(block)
            carry = buf[-_RAW_CARRY:]
    finally:
        f.close()
        probe.close()
