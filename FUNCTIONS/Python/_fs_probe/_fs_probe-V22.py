def _fs_probe(b):
    """Return the filesystem token for a partition-start window, or None."""
    if len(b) < 64:
        return None
    if b[0:6] == b"LUKS\xba\xbe":
        return "luks"
    if b[3:11] == b"NTFS    ":
        return "ntfs"
    if b[3:8] == b"EXFAT ":
        return "exfat"
    if b[54:59] == b"FAT16":
        return "fat16"
    if b[54:59] == b"FAT12":
        return "fat12"
    if b[82:87] == b"FAT32":
        return "fat32"
    if b[64:72] == b"_BHRfS_M":
        return "btrfs"
    if b[0:4] == b"XFSB":
        return "xfs"
    if b[52:60] in (b"ReIsErFs", b"ReIsEr2Fs", b"ReIsEr3Fs", b"ReIsEr4Fs"):
        return "reiserfs"
    if len(b) >= 1026 and b[1024:1026] in (b"H+", b"HX"):
        return "hfs"
    if len(b) >= 1082 and b[1080:1082] == b"\x53\xef":     # ext superblock magic
        return "ext"
    if len(b) >= 1062 and b[1052:1062] == b"SWAPSPACE2":
        return "swap"
    return None
