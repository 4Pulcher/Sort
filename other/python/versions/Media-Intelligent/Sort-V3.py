#!/usr/bin/env python3
"""Sort-V3.py - media-intelligent line, edition V3 (Python equivalent of Sort-V3.sh)

v2.2 rev 3 era: emoji status icons in the terminal output.

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
    sys.exit(editions.run(sys.argv[1:], "media-intelligent", 3))
