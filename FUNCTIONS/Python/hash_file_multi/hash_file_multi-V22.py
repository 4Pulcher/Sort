def hash_file_multi(path: Path, algo_keys) -> dict:
    """Read the file once and compute every requested algorithm in one pass."""
    digests = {kw: hashlib.new(HASH_ALGOS.get(kw, kw.replace("sum", "")) or "md5")
               for kw in algo_keys}
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            for d in digests.values():
                d.update(chunk)
    return {kw: d.hexdigest() for kw, d in digests.items()}
