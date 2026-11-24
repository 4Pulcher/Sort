# functions package - the Python equivalent of the Sort.sh function library
#
# Layout mirrors the shell `functions/` modules of the lineage:
#   colors.py   <- functions/colors     ANSI + icon tokens
#   ui.py       <- functions/ui         output, translations (V17.1 heritage)
#   mime.py     <- functions/mime       magic-byte sniffing (replaces `file`)
#   image.py    <- functions/imagemagick  native dimension parsing (replaces `identify`)
#   hash.py     <- functions/hash       checksum keywords (replaces md5sum/sha*sum)
#   file.py     <- functions/file       per-file facts, timestamps, size labels
#   exif.py     <- functions/exif      native JPEG EXIF parsing (replaces ExifTool)
#   tags.py     <- functions/tags       native ID3v1/ID3v2 parsing (replaces ExifTool)
#   compression.py <- functions/compression  zip/tar inspection (stdlib)
#   system.py   <- functions/system     XDG trash, shred, undo (V14-V15 heritage)
#   core.py     <- functions/core       engine: template language, organizer
#   deps.py     <- functions/deps       runtime capability checks
#   docs.py     <- functions/docs       man page + feature map
#   editions.py <- per-version capability sets for versions/ wrappers
#   testing.py  <- self-test suite
#
# All modules use ONLY the Python standard library. The fast, tested engine
# lives in ../Sort.py and is imported here (sortpy.ENGINE).

import importlib.util
import os
import sys
from pathlib import Path

_PKG_DIR = Path(__file__).resolve().parent
_ENGINE_PATH = _PKG_DIR.parent / "Sort.py"


def _load_engine():
    spec = importlib.util.spec_from_file_location("sortpy_engine", _ENGINE_PATH)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["sortpy_engine"] = mod
    spec.loader.exec_module(mod)
    return mod


ENGINE = _load_engine()

# Re-export the engine surface so `from functions import X, Y` just works.
from sortpy_engine import (  # noqa: E402,F401
    UI, FileFacts, HASH_ALGOS, Organizer, Options, TemplateEngine,
    TYPE_FILTERS, decimal_size_label, gather_facts, hash_file,
    image_dimensions, resolution_format_label, run_self_test,
    sniff_mime, slugify,
)
