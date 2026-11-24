"""functions.file - per-file facts.

Python equivalent of the shell `functions/file` module: timestamps
(created/modified/accessed, stat-based), size labels (V2.2 decimal unit
tokens) and the FileFacts record consumed by the template engine.
"""

import datetime
from pathlib import Path

from . import ENGINE

FileFacts = ENGINE.FileFacts
gather_facts = ENGINE.gather_facts
decimal_size_label = ENGINE.decimal_size_label
run_self_test = ENGINE.run_self_test


def file_created(path: Path) -> datetime.datetime:
    st = Path(path).stat()
    ts = getattr(st, "st_birthtime", None) or st.st_mtime
    return datetime.datetime.fromtimestamp(ts)


def file_modified(path: Path) -> datetime.datetime:
    return datetime.datetime.fromtimestamp(Path(path).stat().st_mtime)


def file_accessed(path: Path) -> datetime.datetime:
    return datetime.datetime.fromtimestamp(Path(path).stat().st_atime)


def format_datetime_value(style: str, dt: datetime.datetime) -> str:
    """created-date / modified-time / ... value formatting (V17 keywords)."""
    key = style.rsplit("-", 1)[0] if "-" in style else style
    fmt = "%Y-%m-%d-%H-%M-%S"
    if style.endswith("-time"):
        fmt = "%H-%M-%S"
    elif style.endswith("-date"):
        fmt = "%Y-%m-%d"
    return dt.strftime(fmt)


def bytes_value(facts) -> str:
    """The V9.4-era `bytes` keyword: raw byte count as a string."""
    return str(facts.size)


__all__ = ["FileFacts", "gather_facts", "decimal_size_label",
           "file_created", "file_modified", "file_accessed",
           "format_datetime_value", "bytes_value", "run_self_test"]
