#!/usr/bin/env python3
"""Sort-V6.py - metadata-driven line, edition V6 (Python equivalent of Sort-V6.sh)

Resolve_Value language: lower:/upper:/raw: prefixes and first-match fallbacks.

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
    sys.exit(editions.run(sys.argv[1:], "metadata-driven", 6))
