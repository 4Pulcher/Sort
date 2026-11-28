"""functions.system - trash, shred, undo (V14-V15 Safe-Transport heritage).

Python equivalent of the shell `functions/system` module. The freedesktop
trash is implemented natively (no `trash-put`), shred uses os.urandom
(no `shred` binary), undo replays the JSONL action log (no jq/awk).
"""

import datetime
import json
import os
import shutil
from pathlib import Path

from . import ENGINE

freedesktop_trash = ENGINE.freedesktop_trash
shred_file = ENGINE.shred_file
undo_log = ENGINE.undo_log


def trash_root() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME",
                               Path.home() / ".local/share")) / "Trash"


def empty_trash_dirs() -> None:
    for sub in ("files", "info"):
        (trash_root() / sub).mkdir(parents=True, exist_ok=True)


def restore_from_trash(name: str, original: str) -> bool:
    """Restore a trashed file by name to its original path."""
    src = trash_root() / "files" / name
    if not src.exists():
        return False
    Path(original).parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), original)
    info = trash_root() / "info" / (name + ".trashinfo")
    if info.exists():
        info.unlink()
    return True


def now_iso() -> str:
    return datetime.datetime.now().isoformat()


__all__ = ["freedesktop_trash", "shred_file", "undo_log",
           "trash_root", "empty_trash_dirs", "restore_from_trash", "now_iso"]
