def _magic_match(h: str, off: int, sig: str) -> bool:
    """True when sig (hex, '?' = any nibble) matches h at byte offset off."""
    pos = off * 2
    if len(h) < pos + len(sig):
        return False
    for i, c in enumerate(sig):
        if c != "?" and h[pos + i] != c:
            return False
    return True
