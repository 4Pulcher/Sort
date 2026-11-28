def sniff_mime(path: Path, head: bytes | None = None) -> tuple[str, str]:
    """Return (mime-main, mime-sub) using magic bytes then heuristics."""
    try:
        if head is None:
            with open(path, "rb") as f:
                head = f.read(512)
    except OSError:
        return ("unknown", "unknown")
    if not head:
        return ("empty", "empty")

    hit = None
    for off, magic, mime in BINARY_SIGNATURES:
        if head[off:off + len(magic)] == magic:
            hit = mime
            break

    if hit:
        # container refinements
        if head.startswith(b"RIFF"):
            if head[8:12] == b"WAVE":
                return ("audio", "wav")
            if head[8:12] == b"AVI ":
                return ("video", "avi")
            if head[8:12] == b"WEBP":
                return ("image", "webp")
            return hit
        if head.startswith(b"\x1aE\xdf\xa3"):
            if b"webm" in head[:64]:
                return ("video", "webm")
            return ("video", "matroska")
        if head.startswith(b"PK\x03\x04"):
            return ("archive", "zip")
        return hit

    # binary oracle failed: text heuristics (Pascal SniffTextMime heritage)
    sample = head[:512]
    sample = bytes(ch for ch in sample if ch in (9, 10, 13) or 32 <= ch < 127 or ch >= 128)
    if all(32 <= b < 127 or b in (9, 10, 13) for b in head[:256]) or head[:1] in (b"\n", b"\r", b" ", b"\t"):
        for rx, sub in TEXT_SNIFFERS:
            if rx.search(sample):
                return ("text", sub)
        return ("text", "plain")

    # fall back to python-mimetypes by extension (stdlib)
    guessed, _ = mimetypes.guess_type(path.name)
    if guessed and "/" in guessed:
        main, _, sub = guessed.partition("/")
        return (main, sub or "unknown")
    return ("binary", "unknown")
