def _fs_norm(fmt):
    """Normalize a user-supplied format token (case/aliases)."""
    f = fmt.strip().lower()
    if f in ("ext2", "ext3", "ext4"):
        f = "ext"
    if f in ("hfs+", "hfsx", "hfsplus"):
        f = "hfs"
    return f
