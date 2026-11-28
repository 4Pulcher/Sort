def run_fs_scan(fs_path, formats, mode, target, log=None) -> int:
    """Report (dummy) or carve (copy) per-partition signature hits."""
    if mode in ("move", "remove", "trash", "shred"):
        print(f"SCAN: --scan supports dummy and copy only "
              f"(mode '{mode}' refused)")
        return 64
    fmts = []
    for tok in (formats or "all").split(","):
        tok = _fs_norm(tok)
        if tok == "":
            continue
        if tok not in _FS_FORMATS:
            print(f"SCAN: unknown filesystem format '{tok}' "
                  f"(known: {','.join(_FS_FORMATS)})")
            return 64
        fmts.append(tok)
    if not fmts or "all" in fmts:
        fmts = [f for f in _FS_FORMATS if f != "all"]

    res = fs_partitions(fs_path)
    if res is None:
        return 66
    fsize, parts = res
    print(f"SCAN: {fs_path}")
    for i, (start, size, fst, status) in enumerate(parts, 1):
        sz = f"~{size}" if status == "lost" else f"{size}"
        print(f"  part {i}: 0x{start:012x} {start} {sz} "
              f"{fst or 'unknown'} {status}")
    nlist = sum(1 for p in parts if p[3] == "listed")
    print(f"SCAN: {len(parts)} partitions found "
          f"({nlist} listed, {len(parts) - nlist} lost)")

    todo = []
    for i, (start, size, fst, status) in enumerate(parts):
        if not fst or fst not in fmts or size <= 0:
            continue
        todo.append(i)
    lf = open(log, "a", encoding="utf-8") if log else None
    srcf = open(fs_path, "rb", buffering=0)
    total = 0
    scanned = 0
    rc = 0
    try:
        for i in todo:
            start, size, fst, status = parts[i]
            print(f"SCAN-PART {i + 1} {fst} 0x{start:012x} {size}")
            nhits = 0
            for hit, name, exts, hsize, exact in \
                    scan_raw_range(fs_path, start, start + size):
                if "filesystem" in name or name == "Linux swap area":
                    continue      # partition signature, not a file fragment
                broken = _fs_overlap(parts, i, hit, hsize)
                total += 1
                nhits += 1
                print(f"  hit: 0x{hit:012x} {hit} {name} -> "
                      f"{exts.split(',')[0]} (carve {hsize} bytes"
                      f"{'' if exact else ', capped'}"
                      f"{', broken' if broken else ''})")
                if mode != "copy":
                    continue
                ext = exts.split(",")[0]
                outdir = (target / "FS-CARVE" /
                          f"p{i + 1}-{start:012x}")
                while True:
                    os.makedirs(outdir, exist_ok=True)
                    dest = outdir / f"{hit:012x}.{ext}"
                    ok, oos = _fs_write(srcf, dest, hit, hsize)
                    if ok:
                        break
                    if oos and sys.stdin is not None and \
                            sys.stdin.isatty():
                        print(f"SCAN: out of space at {outdir}")
                        newt = input("SCAN: new target directory "
                                     "(empty = abort): ").strip()
                        if not newt:
                            print("SCAN: copy aborted by user")
                            return 65
                        outdir = (Path(newt) / "FS-CARVE" /
                                  f"p{i + 1}-{start:012x}")
                        continue
                    print(f"SCAN: cannot write {dest}")
                    return 65
                print(f"  carved: {dest}")
                if lf:
                    entry = {"action": "carved",
                             "src": f"{fs_path}@{hit}",
                             "dst": str(dest), "part": i + 1}
                    if broken:
                        entry["broken"] = True
                    lf.write(json.dumps(entry) + "\n")
            scanned += 1
            print(f"SCAN-PART {i + 1}: {nhits} signatures found")
    finally:
        srcf.close()
        if lf:
            lf.close()
    print(f"SCAN: done, {total} signatures in {scanned} partitions")
    return rc
