"""functions.core - the engine surface.

Python equivalent of the shell `functions/core` module: the template
language, the organizer loop and the option types. Implementation lives in
the single-file engine (../Sort.py); this module re-exports it and, once
`functions.editions` is imported, the engine speaks the extended keyword
language (bytes / exif-* / id3-*).
"""

from . import ENGINE

Organizer = ENGINE.Organizer
Options = ENGINE.Options
TemplateEngine = ENGINE.TemplateEngine   # EditionTemplate when editions imported
TYPE_FILTERS = ENGINE.TYPE_FILTERS
FileFacts = ENGINE.FileFacts
slugify = ENGINE.slugify
UI = ENGINE.UI

__all__ = ["Organizer", "Options", "TemplateEngine", "TYPE_FILTERS",
           "FileFacts", "slugify", "UI"]
