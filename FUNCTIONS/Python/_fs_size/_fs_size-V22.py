def _fs_size(f):
    """True byte size of an open file or block device (best effort)."""
    try:
        f.seek(0, 2)
        n = f.tell()
        if n > 0:
            return n
    except OSError:
        pass
    try:                                    # Linux block devices
        import fcntl
        import struct as _st
        buf = fcntl.ioctl(f.fileno(), 0x80081272, _st.pack("Q", 0))  # BLKGETSIZE64
        return _st.unpack("Q", buf)[0]
    except Exception:
        return 0
