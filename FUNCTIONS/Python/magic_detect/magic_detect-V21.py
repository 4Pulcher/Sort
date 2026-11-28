def magic_detect(hexstr: str):
    """Match a hex signature against the table -> (name, exts) or ('?', '')."""
    h = hexstr.lower()
    # MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376
    if (len(h) >= 754 and h[0:2] == "47"
            and h[376:378] == "47" and h[752:754] == "47"):
        return "MPEG-TS", "ts,m2ts,mts"
    for off, sig, name, exts in _MAGIC_TABLE:
        if _magic_match(h, off, sig):
            return name, exts
    return "?", ""
