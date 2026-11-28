def read_exif(path) -> dict:
    """Parse EXIF from a JPEG file. Returns {} when absent/unreadable."""
    try:
        data = Path_read(path)
    except OSError:
        return {}
    if not data.startswith(b"\xff\xd8\xff"):
        return {}
    out: dict = {}
    pos = 2
    n = len(data)
    while pos + 4 < n:
        if data[pos] != 0xFF:
            pos += 1
            continue
        code = data[pos + 1]
        if code in (0xD8, 0x01) or 0xD0 <= code <= 0xD7:
            pos += 2
            continue
        if pos + 4 > n:
            break
        seglen = int.from_bytes(data[pos + 2:pos + 4], "big")
        if seglen < 2 or pos + 2 + seglen > n:
            break
        if code == 0xE1 and data[pos + 4:pos + 10] == b"Exif\x00\x00":
            out.update(_parse_tiff(data, pos + 10))
            break
        pos += 2 + seglen
    return out
