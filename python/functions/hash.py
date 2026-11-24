"""functions.hash - checksum keywords.

Python equivalent of the shell `functions/hash` module: replaces md5sum /
sha1sum / sha224sum / sha256sum / sha384sum / sha512sum with hashlib.
"""

from . import ENGINE

hash_file = ENGINE.hash_file
HASH_ALGOS = ENGINE.HASH_ALGOS

__all__ = ["hash_file", "HASH_ALGOS"]
