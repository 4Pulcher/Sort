"""functions.ui - terminal output and translations.

Python equivalent of the shell `functions/ui` module (V17.1 multilingual
heritage). Colors/icons come from functions.colors; the engine UI class is
re-exported so callers have one interface.
"""

from . import ENGINE, colors

UI = ENGINE.UI
TRANSLATIONS = ENGINE.TRANSLATIONS

__all__ = ["UI", "TRANSLATIONS", "colors"]
