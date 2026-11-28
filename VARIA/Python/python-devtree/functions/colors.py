"""functions.colors - ANSI color and emoji icon tokens.

Python equivalent of the shell `functions/colors` module. Pure Python:
no `tput`, no `terminfo` calls (the shell edition shelled out to tput).
"""

CATEGORY_STYLES = {
    "bold": ("1",),
    "dim": ("2",),
    "label": ("94",),
    "path": ("37",),
    "info": ("36",),
    "ok": ("32",),
    "warn": ("33",),
    "err": ("31",),
}

ICONS = {
    "info": "\u2139\ufe0f", "ok": "\u2705", "warn": "\u26a0\ufe0f",
    "error": "\u274c", "skip": "\u23ed\ufe0f", "dir": "\U0001f4c1",
    "file": "\U0001f4c4", "link": "\U0001f517", "copy": "\U0001f4cb",
    "move": "\U0001f69a", "remove": "\U0001f5d1\ufe0f", "mime": "\U0001f3f7",
    "target": "\U0001f3af", "name": "\U0001f4dd", "hash": "\U0001f511",
    "clean": "\U0001f9f9", "done": "\U0001f3c1", "test": "\U0001f9ea",
}


def paint(text: str, *codes: str, enabled: bool = True) -> str:
    """Wrap text in ANSI escapes; no-op when colors are disabled."""
    if not enabled or not codes:
        return text
    return "\033[" + ";".join(codes) + "m" + text + "\033[0m"


def icon(key: str, enabled: bool = True) -> str:
    if not enabled:
        return ""
    return ICONS.get(key, "") + " "
