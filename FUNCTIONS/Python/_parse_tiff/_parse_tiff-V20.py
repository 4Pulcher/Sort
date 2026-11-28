def _parse_tiff(buf: bytes, tiff: int) -> dict:
    endian = buf[tiff:tiff + 2]
    if endian == b"II":
        e = "<"
    elif endian == b"MM":
        e = ">"
    else:
        return {}
    if struct.unpack(e + "H", buf[tiff + 2:tiff + 4])[0] != 42:
        return {}
    ifd_off = tiff + struct.unpack(e + "I", buf[tiff + 4:tiff + 8])[0]
    if ifd_off + 2 > len(buf):
        return {}
    out: dict = {}
    try:
        count = struct.unpack(e + "H", buf[ifd_off:ifd_off + 2])[0]
        for i in range(min(count, 256)):
            entry = ifd_off + 2 + i * 12
            if entry + 12 > len(buf):
                break
            tag, typ, cnt = struct.unpack(e + "HHI", buf[entry:entry + 8])
            if tag not in EXIF_TAGS:
                continue
            if typ == 2:                      # ASCII
                if cnt <= 4:
                    raw = buf[entry + 8:entry + 8 + cnt]
                else:
                    off = struct.unpack(e + "I", buf[entry + 8:entry + 12])[0]
                    raw = buf[tiff + off:tiff + off + cnt]
                out[EXIF_TAGS[tag]] = raw.split(b"\x00")[0].decode("utf-8", "replace")
            elif typ == 3:                    # SHORT (inline)
                out[EXIF_TAGS[tag]] = struct.unpack(e + "H", buf[entry + 8:entry + 10])[0]
            elif typ == 4:                    # LONG (inline for count 1)
                out[EXIF_TAGS[tag]] = struct.unpack(e + "I", buf[entry + 8:entry + 12])[0]
            elif typ == 10:                   # RATIONAL
                off = struct.unpack(e + "I", buf[entry + 8:entry + 12])[0]
                num, den = struct.unpack(e + "II", buf[tiff + off:tiff + off + 8])
                out[EXIF_TAGS[tag]] = num / den if den else 0
    except struct.error:
        pass
    return out
