def magic_hex(path) -> str:
    """First 16 bytes of the file as one lowercase hex string."""
    try:
        with open(path, "rb") as fh:
            return fh.read(16).hex()
    except OSError:
        return ""
