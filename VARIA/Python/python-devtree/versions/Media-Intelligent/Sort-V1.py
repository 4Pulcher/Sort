#!/usr/bin/env python3
"""Sort-V1.py - media-intelligent line, edition V1 (Python equivalent of Sort-V1.sh)

v2.2 rev 1 era: Media-Intelligent organizing, no icons, no threads.

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
    sys.exit(editions.run(sys.argv[1:], "media-intelligent", 1))
