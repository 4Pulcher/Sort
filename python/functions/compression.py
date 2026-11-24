"""functions.compression - archive inspection (stdlib only).

Python equivalent of the shell `functions/compression` module: identifies
zip/tar/gzip/bzip2/xz archives and counts entries using zipfile/tarfile.
"""

import bz2
import gzip
import lzma
import tarfile
import zipfile
from pathlib import Path


def sniff_archive(path) -> dict:
    """Return {'kind': ..., 'entries': n|None, 'compressed': bool}."""
    p = Path(path)
    out = {"kind": "unknown", "entries": None, "compressed": False}
    try:
        if zipfile.is_zipfile(p):
            out["kind"] = "zip"
            with zipfile.ZipFile(p) as z:
                out["entries"] = sum(1 for i in z.infolist() if not i.is_dir())
            return out
        if tarfile.is_tarfile(p):
            out["kind"] = "tar"
            with tarfile.open(p) as t:
                out["entries"] = len([m for m in t.getmembers() if m.isfile()])
            return out
        with open(p, "rb") as f:
            head = f.read(16)
        magic = {
            b"\x1f\x8b": ("gzip", True), b"BZh": ("bzip2", True),
            b"\xfd7zXZ\x00": ("xz", True),
            b"7z\xbc\xaf\x27\x1c": ("7z", False),
            b"Rar!\x1a\x07": ("rar", False),
        }
        for sig, (kind, comp) in magic.items():
            if head.startswith(sig):
                out.update(kind=kind, compressed=comp)
                break
    except (OSError, tarfile.TarError, zipfile.BadZipFile, EOFError):
        pass
    return out


__all__ = ["sniff_archive"]
