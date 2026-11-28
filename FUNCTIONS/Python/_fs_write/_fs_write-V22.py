def _fs_write(srcf, dest, hit, size):
    """Carve one fragment; return (ok, oos). oos = out of space."""
    import errno
    srcf.seek(hit)
    with open(dest, "wb") as dst:
        remaining = size
        while remaining > 0:
            buf = srcf.read(min(remaining, 1 << 20))
            if not buf:
                break
            try:
                dst.write(buf)
            except OSError as exc:
                return False, exc.errno == errno.ENOSPC
            remaining -= len(buf)
    return True, False
