"""functions.docs - man page and lineage feature map.

Python equivalent of the shell `functions/docs` module (the heredoc MANPAGE
and per-version notes). Text lives here; Sort.py re-uses it.
"""

from . import ENGINE

MANPAGE = ENGINE.MANPAGE
FEATURE_MAP = """
| Bash era | Feature | Python location |
|---|---|---|
| V1.x-V4.x | organize flow, MIME keywords, template destination paths | functions.core |
| V5.x | Media-Intelligent renames: hash/size/format keywords | functions.hash / functions.file |
| V6.x | single-pass mode parsing, type filters | functions.core TYPE_FILTERS |
| V7-V8 | source/target argument model, per-file templates | Sort.py CLI + core |
| V9.x | safe copy/move/remove, dry-run default, self-tests | default dummy mode, functions.testing |
| V9.5 / V17 | lower:/upper:/raw: prefixes, fallback pipes, slugified names | functions.core TemplateEngine |
| V10.x | MIME main/sub model, emoji icons, empty-dir cleanup | functions.mime, functions.colors |
| V11.0 | fully self-contained single-file edition | Sort.py |
| V12.x | threaded worker pool | engine --jobs |
| V13.x | stable, heavily documented generation | docs + docstrings |
| V14-V15 | Safe Transport (trash/shred) + undo log | functions.system |
| V16-V17 | rewrite era: modular library + editions | functions/ package + versions/ |
"""

__all__ = ["MANPAGE", "FEATURE_MAP"]
