def fs_partitions(path):
    """[(start, size, fstype, status)] - status 'listed' or 'lost'.
    fstype may be None when a table entry exists but no filesystem was
    detected at its start (raw / unknown partition)."""
    try:
        f = open(path, "rb", buffering=0)
    except OSError as exc:
        print(f"SCAN: cannot open {path}: {exc}")
        return None
    with f:
        fsize = _fs_size(f)
        parts = []
        for start, size, tb in _fs_listed(f, fsize):
            f.seek(start)
            fst = _fs_probe(f.read(_FS_PROBE_LEN))
            parts.append([start, size, fst, "listed"])
        if fsize <= 0:
            if not parts:
                print(f"SCAN: cannot determine size of {path}")
                return None
            fsize = max(p[0] + p[1] for p in parts)
        inside = [(p[0], p[0] + p[1]) for p in parts]
        off = 0
        while off < fsize:
            if not any(a <= off < b for a, b in inside):
                f.seek(off)
                w = f.read(_FS_PROBE_LEN)
                fst = _fs_probe(w)
                if fst:
                    nxt = fsize
                    for a, b in inside:
                        if a > off:
                            nxt = min(nxt, a)
                    parts.append([off, nxt - off, fst, "lost"])
            off += _FS_SECTOR
        parts.sort(key=lambda p: p[0])
        # keep 'listed' first in numbering: rebuild index by status then start
        listed = [p for p in parts if p[3] == "listed"]
        lost = [p for p in parts if p[3] == "lost"]
        return fsize, listed + lost
