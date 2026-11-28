def _decode_text(enc: int, raw: bytes) -> str:
    raw = raw.split(b"\x00", 1)[0] if enc in (0, 3) else raw
    if enc == 0:
        return raw.decode("latin-1", "replace")
    if enc == 1:
        if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
            return raw.decode("utf-16", "replace")
        return raw.decode("utf-16-le", "replace")
    if enc == 2:
        return raw.decode("utf-16-be", "replace")
    return raw.decode("utf-8", "replace")
