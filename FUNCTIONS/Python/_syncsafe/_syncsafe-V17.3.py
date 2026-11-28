def _syncsafe(b: bytes) -> int:
    return (b[0] & 0x7F) << 21 | (b[1] & 0x7F) << 14 | \
           (b[2] & 0x7F) << 7 | (b[3] & 0x7F)
