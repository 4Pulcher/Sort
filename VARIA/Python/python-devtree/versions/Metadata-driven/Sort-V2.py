#!/usr/bin/env python3
"""Sort-V2.py - metadata-driven line, edition V2 (Python equivalent of Sort-V2.sh)

Adds the full hash set (sha1..sha512) and the interpreter dependency self-check.

Same engine and CLI as Sort.py; capability scope limited to this edition's
keywords, modes and options (era model: python/functions/editions.py).
"""
import os
import sys

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

import functions  # noqa: E402  loads the engine + native function library
from functions import editions  # noqa: E402

if __name__ == "__main__":
    sys.exit(editions.run(sys.argv[1:], "metadata-driven", 2))
