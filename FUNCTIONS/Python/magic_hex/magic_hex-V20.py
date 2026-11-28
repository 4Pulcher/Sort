def magic_hex(path) -> str:
    """First 32774 bytes of the file as one lowercase hex string."""
    try:
        with open(path, "rb") as fh:
            return fh.read(_MAGIC_SPAN).hex()
    except OSError:
        return ""
