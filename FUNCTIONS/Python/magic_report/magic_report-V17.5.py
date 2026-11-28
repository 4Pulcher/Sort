def magic_report(path) -> str:
    """One four-line report block for a single file."""
    h = magic_hex(path) or "(empty)"
    name, exts = magic_detect(h)
    ext = path.suffix.lstrip(".").lower() if path.suffix else "(none)"
    if name == "?":
        verdict = "UNKNOWN"
    elif ext == "(none)":
        verdict = "NO-EXT"
    elif ext in exts.split(","):
        verdict = "MATCH"
    else:
        verdict = "MISMATCH"
    return (f"{path}\nmagic: {h[:32]}\ndetected: {name}\n"
            f"extension: {ext}\nverdict: {verdict}")
