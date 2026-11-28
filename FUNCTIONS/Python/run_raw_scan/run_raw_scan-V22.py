def run_raw_scan(raw_path, mode: str, target, log=None) -> int:
    """Report (dummy) or carve (copy) the hits found in a raw device/image."""
    if mode in ("move", "remove", "trash", "shred"):
        print(f"RAW-SCAN: --scan-raw supports dummy and copy only "
              f"(mode '{mode}' refused)")
        return 64
    ext_of = lambda exts: (exts.split(",")[0] if exts else "bin")
    count = 0
    outdir = target / "RAW-CARVE"
    if mode == "copy":
        outdir.mkdir(parents=True, exist_ok=True)
    print(f"RAW-SCAN: {raw_path}")
    for hit, name, exts, size, exact in scan_raw(raw_path):
        count += 1
        print(f"  hit: 0x{hit:012x} {hit} {name} -> {ext_of(exts)} "
              f"(carve {size} bytes{'' if exact else ', capped'})")
        if mode == "copy":
            dest = outdir / (f"{hit:012x}.{ext_of(exts)}")
            try:
                with open(raw_path, "rb") as src, open(dest, "wb") as dst:
                    src.seek(hit)
                    remaining = size
                    while remaining > 0:
                        chunk = src.read(min(1 << 20, remaining))
                        if not chunk:
                            break
                        dst.write(chunk)
                        remaining -= len(chunk)
                print(f"  carved: {dest}")
                if log:
                    with open(log, "a", encoding="utf-8") as lf:
                        lf.write(json.dumps({"action": "carved",
                                             "src": f"{raw_path}@{hit}",
                                             "dst": str(dest)}) + "\n")
            except OSError as exc:
                print(f"  carve failed at 0x{hit:012x}: {exc}")
    print(f"RAW-SCAN: {count} signatures found")
    return 0
