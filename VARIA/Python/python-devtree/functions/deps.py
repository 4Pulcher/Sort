"""functions.deps - runtime capability checks.

Python equivalent of the shell `functions/deps` module. The shell version
verified ~20 external binaries; the Python edition needs none of them,
so this module verifies interpreter capabilities instead.
"""

import os
import platform
import sys

REQUIRED_PYTHON = (3, 9)

# External commands the Bash editions required -> Python replacement
REPLACED_COMMANDS = {
    "file": "functions.mime (magic bytes, stdlib)",
    "identify": "functions.image (struct parsers)",
    "ffprobe": "functions.mime (container sniffing only)",
    "exiftool": "functions.exif + functions.tags",
    "md5sum": "functions.hash (hashlib)",
    "sha256sum": "functions.hash (hashlib)",
    "trash-put": "functions.system (freedesktop trash)",
    "shred": "functions.system (os.urandom overwrite)",
    "stat": "os.stat / pathlib",
    "date": "datetime",
    "tput": "functions.colors (static ANSI)",
}


def report() -> dict:
    st = os.stat(".")
    return {
        "python": platform.python_version(),
        "python_ok": sys.version_info >= REQUIRED_PYTHON,
        "birthtime_available": hasattr(st, "st_birthtime"),
        "platform": platform.system().lower(),
        "external_commands_required": 0,
    }


def assert_ready() -> None:
    if sys.version_info < REQUIRED_PYTHON:
        raise SystemExit(
            f"Sort.py requires Python {REQUIRED_PYTHON[0]}.{REQUIRED_PYTHON[1]}+ "
            f"(found {platform.python_version()})")


__all__ = ["report", "assert_ready", "REPLACED_COMMANDS", "REQUIRED_PYTHON"]
