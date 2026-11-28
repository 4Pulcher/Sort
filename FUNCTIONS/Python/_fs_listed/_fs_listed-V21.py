def _fs_listed(f, fsize):
    """MBR + GPT entries -> [(start, size, type_byte_or_None)]."""
    out = []
    f.seek(0)
    mbr = f.read(512)
    if len(mbr) < 512 or mbr[510:512] != b"\x55\xaa":
        return out
    types = [mbr[446 + 16 * i + 4] for i in range(4)]
    if 0xEE in types:                       # GPT protective MBR
        f.seek(512)
        hdr = f.read(512)
        if hdr[0:8] == b"EFI PART":
            import struct as _st
            elba = _st.unpack("<Q", hdr[72:80])[0]
            nent = _st.unpack("<I", hdr[80:84])[0]
            esz = _st.unpack("<I", hdr[84:88])[0]
            if esz >= 128 and nent > 0 and nent * esz <= 4 << 20:
                f.seek(elba * _FS_SECTOR)
                blob = f.read(nent * esz)
                for i in range(nent):
                    e = blob[i * esz:(i + 1) * esz]
                    if len(e) < 128 or not any(e[0:16]):
                        continue
                    first = _st.unpack("<Q", e[32:40])[0]
                    last = _st.unpack("<Q", e[40:48])[0]
                    if last < first:
                        continue
                    start = first * _FS_SECTOR
                    size = (last - first + 1) * _FS_SECTOR
                    if 0 < size <= fsize:
                        out.append((start, size, None))
            return out
    for i in range(4):                      # classic MBR
        tb = types[i]
        if tb in (0x00, 0x05, 0x0F, 0xEE, 0x85):     # empty / extended / GPT
            continue
        import struct as _st
        lba = _st.unpack("<I", mbr[446 + 16 * i + 8:446 + 16 * i + 12])[0]
        nsec = _st.unpack("<I", mbr[446 + 16 * i + 12:446 + 16 * i + 16])[0]
        start = lba * _FS_SECTOR
        size = nsec * _FS_SECTOR
        if nsec > 0 and start + size <= fsize:
            out.append((start, size, tb))
    return out
