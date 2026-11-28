"""functions.mime - magic-byte MIME sniffing.

Python equivalent of the shell `functions/mime` module. Replaces the
`file` command entirely: signatures and text heuristics are evaluated in
pure Python (Pascal FindMime heritage carried into the line).
"""

from . import ENGINE

sniff_mime = ENGINE.sniff_mime
BINARY_SIGNATURES = ENGINE.BINARY_SIGNATURES
TEXT_SNIFFERS = ENGINE.TEXT_SNIFFERS

__all__ = ["sniff_mime", "BINARY_SIGNATURES", "TEXT_SNIFFERS"]
