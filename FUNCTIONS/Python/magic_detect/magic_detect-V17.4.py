def magic_detect(hexstr: str):
    """Match a hex signature against the table -> (name, exts) or ('?', '')."""
    h = hexstr.lower()
    if len(h) >= 16:
        if h[:8] == "52494646" and h[16:24] == "57454250":
            return "WEBP", "webp"
        if h[:8] == "52494646" and h[16:24] == "57415645":
            return "WAV", "wav"
        if h[8:16] == "66747970":
            return "MP4/MOV", "mp4,mov,m4a,3gp"
    for sig, name, exts in _MAGIC_PREFIX:
        if h.startswith(sig):
            return name, exts
    return "?", ""
