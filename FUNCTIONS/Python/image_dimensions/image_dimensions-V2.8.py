def image_dimensions(path: Path) -> tuple[int, int] | None:
    """Parse WxH natively for PNG, GIF, BMP, JPEG, WEBP. No ImageMagick."""
    f = None
    try:
        size = path.stat().st_size
        f = open(path, "rb")
        head = f.read(64)
        if size < 8:
            return None
        if head.startswith(b"\x89PNG") and size >= 24:
            w, h = struct.unpack(">II", head[16:24])
            return (w, h)
        if head[:6] in (b"GIF87a", b"GIF89a"):
            w, h = struct.unpack("<HH", head[6:10])
            return (w, h)
        if head.startswith(b"BM") and size > 26:
            w, h = struct.unpack("<ii", head[18:26])
            return (abs(w), abs(h))
        if head.startswith(b"RIFF") and head[8:12] == b"WEBP":
            if head[12:16] == b"VP8X":
                w = int.from_bytes(head[24:27], "little") + 1
                h = int.from_bytes(head[27:30], "little") + 1
                return (w, h)
            if head[12:16] == b"VP8 ":
                f.seek(26)
                w, h = struct.unpack("<HH", f.read(4))
                return (w, h)
            if head[12:16] == b"VP8L":
                bits = int.from_bytes(head[21:25], "little")
                return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
        if head.startswith(b"\xff\xd8\xff"):
            f.seek(2)
            while True:
                marker = f.read(2)
                if len(marker) < 2:
                    return None
                if marker[0] != 0xFF:
                    return None
                code = marker[1]
                if code == 0xD8 or code == 0x01 or 0xD0 <= code <= 0xD7:
                    continue  # standalone markers
                seglen_bytes = f.read(2)
                if len(seglen_bytes) < 2:
                    return None
                seglen = int.from_bytes(seglen_bytes, "big")
                if code in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6,
                            0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    data = f.read(5)
                    h, w = struct.unpack(">HH", data[1:5])
                    return (w, h)
                f.seek(seglen - 2, 1)
    except (OSError, struct.error):
        return None
    finally:
        if f:
            f.close()
    return None
