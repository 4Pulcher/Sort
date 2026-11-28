def _raw_patterns():
    """(off, name, exts, literal_bytes | None, regex | None) per entry."""
    pats = []
    for off, sig, name, exts in _MAGIC_TABLE:
        if len(sig) < 4:
            continue          # 1-byte signatures are noise on raw media
        if "?" not in sig:
            pats.append((off, name, exts, bytes.fromhex(sig), None))
            continue
        out = b""
        ok = True
        for i in range(0, len(sig), 2):
            hi, lo = sig[i], sig[i + 1]
            if hi == "?" and lo == "?":
                out += b"."
            elif lo == "?":
                cls = bytes(range(int(hi, 16) * 16, int(hi, 16) * 16 + 16))
                out += b"[" + re.escape(cls) + b"]"
            elif hi == "?":
                cls = bytes(range(int(lo, 16), 256, 16))
                out += b"[" + re.escape(cls) + b"]"
            else:
                out += re.escape(bytes([int(sig[i:i + 2], 16)]))
        pats.append((off, name, exts, None, re.compile(out, re.DOTALL)))
    return pats
