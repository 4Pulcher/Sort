"""functions.exif - native JPEG EXIF parsing.

Python equivalent of the shell `functions/exif` module: replaces
ExifTool for the most-used EXIF fields. Reads the APP1 segment and
TIFF IFD0 entries in pure Python (struct only). Returns a dict with:
make, model, orientation, datetime, dt_original, exposure, fnumber, iso.
"""

import struct

EXIF_TAGS = {
    0x010F: "make", 0x0110: "model", 0x0112: "orientation",
    0x0132: "datetime", 0x9003: "dt_original",
    0x829A: "exposure", 0x829D: "fnumber", 0x8827: "iso",
}


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


def Path_read(path, limit: int = 2 << 20) -> bytes:
    with open(path, "rb") as f:
        return f.read(limit)


__all__ = ["read_exif", "EXIF_TAGS"]
