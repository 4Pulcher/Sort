def hash_file(path: Path, algo_key: str) -> str:
    h = hashlib.new(HASH_ALGOS.get(algo_key, algo_key.replace("sum", "") or "md5"))
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()
