def _fs_overlap(parts, pidx, hit, size):
    """True when the fragment [hit, hit+size) leaves its partition or
    crosses into another one (overwritten data -> 'broken')."""
    start, psize = parts[pidx][0], parts[pidx][1]
    end = start + psize
    if hit + size > end:
        return True
    for i, p in enumerate(parts):
        if i == pidx:
            continue
        if hit < p[0] + p[1] and hit + size > p[0]:
            return True
    return False
