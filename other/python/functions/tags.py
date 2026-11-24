"""functions.tags - native ID3v1/ID3v2 audio tag parsing.

Python equivalent of the shell `functions/tags` module: replaces
ExifTool for MP3 tags. Pure Python read-only parsing.
Returns dict keys: title, artist, album, year, track, genre.
"""

import struct


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


def _syncsafe(b: bytes) -> int:
    return (b[0] & 0x7F) << 21 | (b[1] & 0x7F) << 14 | \
           (b[2] & 0x7F) << 7 | (b[3] & 0x7F)


def read_id3(path) -> dict:
    """Read ID3v2 (header) and ID3v1 (tail) tags from an MP3 file."""
    out: dict = {}
    try:
        with open(path, "rb") as f:
            head = f.read(1 << 20)
            f.seek(-128, 2)
            tail = f.read(128)
    except OSError:
        return out

    # ---- ID3v2 ----
    if head[:3] == b"ID3":
        ver = head[3]
        size = _syncsafe(head[6:10])
        pos = 10
        end = min(10 + size, len(head))
        name = {b"TIT2": "title", b"TPE1": "artist", b"TALB": "album",
                b"TYER": "year", b"TDRC": "year", b"TRCK": "track",
                b"TCON": "genre"}
        while pos + 10 <= end:
            fid = head[pos:pos + 4]
            if not fid.strip(b"\x00") or fid[0] not in b"ATC":
                break
            if ver == 4:
                fsize = _syncsafe(head[pos + 4:pos + 8])
            else:
                fsize = int.from_bytes(head[pos + 4:pos + 8], "big")
            if fsize <= 0 or pos + 10 + fsize > len(head):
                break
            enc = head[pos + 10]
            value = _decode_text(enc, head[pos + 11:pos + 10 + fsize])
            if fid in name and value:
                out[name[fid]] = value
            pos += 10 + fsize

    # ---- ID3v1 ----
    if len(tail) == 128 and tail[:3] == b"TAG":
        def txt(o: int, ln: int) -> str:
            return tail[o:o + ln].strip(b"\x00 ").decode("latin-1", "replace")
        v1 = {
            "title": txt(3, 30), "artist": txt(33, 30), "album": txt(63, 30),
            "year": txt(93, 4),
        }
        if tail[125:126] == b"\x00" and tail[126]:
            v1["track"] = str(tail[126])
        for k, v in v1.items():
            out.setdefault(k, v)
    return out


__all__ = ["read_id3"]
