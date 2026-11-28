def Path_read(path, limit: int = 2 << 20) -> bytes:
    with open(path, "rb") as f:
        return f.read(limit)
