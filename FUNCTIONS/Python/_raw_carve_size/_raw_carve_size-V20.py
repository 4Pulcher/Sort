def _raw_carve_size(head: bytes, name: str, cap: int):
    """Estimate the fragment length -> (size, exact). exact=True means the
    format itself said where it ends; False means the cap was applied."""
    try:
        if name.startswith("PNG image"):
            pos = 8
            while pos + 12 <= len(head):
                import struct as _st
                clen = _st.unpack(">I", head[pos:pos + 4])[0]
                ctype = head[pos + 4:pos + 8]
                pos += 12 + clen             # len + type + data + CRC
                if ctype == b"IEND":
                    return min(pos, cap), True
                if clen > len(head):
                    return min(pos, cap), False
            return min(len(head), cap), False
        if name.startswith("JPEG image"):
            end = head.rfind(b"\xff\xd9")
            return ((end + 2), True) if end != -1 else (min(len(head), cap), False)
        if name.startswith("GIF image"):
            end = head.rfind(b"\x3b", 13)
            return ((end + 1), True) if end != -1 else (min(len(head), cap), False)
        if name.startswith("ZIP/") or name.startswith("ZIP archive"):
            end = head.rfind(b"PK\x05\x06")
            if end != -1 and end + 22 <= len(head):
                import struct as _st
                comment = _st.unpack(">H", head[end + 20:end + 22])[0]
                return end + 22 + comment, True
            return min(len(head), cap), False
        if name.startswith("PDF document"):
            end = head.rfind(b"%%EOF")
            return ((end + 5), True) if end != -1 else (min(len(head), cap), False)
    except Exception:
        pass
    return min(len(head), cap), False
