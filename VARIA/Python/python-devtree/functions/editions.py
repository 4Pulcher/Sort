"""functions.editions - per-version capability sets and wrappers.

This module powers python/versions/: it reproduces, in Python, the exact
feature scope of each edition of the Bash lineage. One tested engine
(Sort.py) runs underneath; each edition gates the keywords, option
flags, modes, modifiers and fallback syntax its Bash counterpart had.

Era sets follow the canonical chronology (VERSIONS.txt on main,
Sort-Versions.md on the vibe branch): the "Metadata-driven" line maps to
the shell safe-modes family (V9.0-V9.5); the "Media-Intelligent" line maps
to the self-labelled v2.2 rev1/rev2/rev3, v3.0, v3.1, v5.1 and v6 editions.
"""

import re
import sys

from . import ENGINE, exif, tags
from . import file as filemod

# ---------------------------------------------------------------------------
# Native tag keywords (the v6 "ExifTool era", implemented with the stdlib)
# ---------------------------------------------------------------------------


def _ensure_extras(facts):
    """Attach exif/id3 dicts to a FileFacts record (created by the engine)."""
    if getattr(facts, "_extras_done", False):
        return facts
    facts.exif = {}
    facts.id3 = {}
    try:
        if facts.mime_main == "image" and facts.mime_sub == "jpeg":
            facts.exif = exif.read_exif(facts.path)
        if (facts.mime_sub == "mpeg"
                or facts.path.suffix.lower() in (".mp3", ".mpga")):
            facts.id3 = tags.read_id3(facts.path)
    except OSError:
        pass
    facts._extras_done = True
    return facts


class EditionTemplate(ENGINE.TemplateEngine):
    """Engine template language extended with the V7-era tag keywords."""

    def keyword_value(self, facts, kw):                     # noqa: D102
        _ensure_extras(facts)
        v = super().keyword_value(facts, kw)
        if v:
            return v
        if kw == "bytes":
            return filemod.bytes_value(facts)
        table = {"exif-make": ("exif", "make"),
                 "exif-model": ("exif", "model"),
                 "exif-datetime": ("exif", "datetime"),
                 "exif-date": ("exif", "datetime"),
                 "exif-orientation": ("exif", "orientation"),
                 "id3-title": ("id3", "title"),
                 "id3-artist": ("id3", "artist"),
                 "id3-album": ("id3", "album"),
                 "id3-year": ("id3", "year")}
        if kw in table:
            src = getattr(facts, table[kw][0], {})
            val = src.get(table[kw][1], "")
            if kw == "exif-date" and val:
                return str(val)[:10]
            return str(val)
        return ""


ENGINE.TemplateEngine = EditionTemplate
_ORIG_GATHER = ENGINE.gather_facts


def _gather_with_extras(path, want_hashes):
    return _ensure_extras(_ORIG_GATHER(path, want_hashes))


ENGINE.gather_facts = _gather_with_extras

# ---------------------------------------------------------------------------
# Keyword epochs
# ---------------------------------------------------------------------------

BASE = {
    "year", "month", "day", "year+month", "year+month+day",
    "created", "modified", "accessed",
    "extension", "mime", "mime-main", "mime-sub", "type",
    "filename", "name", "basename", "stem", "original",
    "size", "format", "size+format",
}
PIXEL = {"pixel-size", "pixel-format", "resolution", "resolution-format"}
HASHES = set(ENGINE.HASH_ALGOS)
TAGS = {"exif-make", "exif-model", "exif-datetime", "exif-date",
        "exif-orientation", "id3-title", "id3-artist", "id3-album", "id3-year"}

ALL_KEYWORDS = BASE | PIXEL | HASHES | TAGS | {"ext-lower", "ext-upper",
                                               "bytes", "random"}


def _md_base():
    return (BASE | {"md5sum", "sha256sum"}) - PIXEL


MD_EPOCHS = {
    1: _md_base(),
    2: _md_base() | HASHES,                       # full hash epoch
    3: _md_base() | HASHES,                       # template engine era
    4: _md_base() | HASHES,                       # context era (same words)
    5: _md_base() | HASHES | {"ext-lower", "bytes"},
    6: _md_base() | HASHES | {"ext-lower", "bytes"},   # + modifiers/fallbacks
}

MI_EPOCHS = {
    1: BASE | HASHES | PIXEL,                      # v2.2 rev1
    2: BASE | HASHES | PIXEL,                      # v2.2 rev2 (cleanup)
    3: BASE | HASHES | PIXEL,                      # v2.2 rev3 (icons)
    4: BASE | HASHES | PIXEL,                      # v3.0 (jobs, threads)
    5: BASE | HASHES | PIXEL,                      # v3.1 (stable)
    6: BASE | HASHES | PIXEL,                      # v5.1 (log)
    7: BASE | HASHES | PIXEL | TAGS | {"bytes"},   # v6: native tag era
}

# ---------------------------------------------------------------------------
# Era definitions
# ---------------------------------------------------------------------------

MD_MODES = {"dummy", "copy", "move", "remove"}
MI_MODES = {"dummy", "copy", "move", "trash", "shred"}

ERAS = {
    # Metadata-driven line (shell safe-modes family)
    ("metadata-driven", 1): dict(
        keywords=MD_EPOCHS[1], modifiers=False, fallbacks=False,
        options=set(), modes=MD_MODES, icons=False,
        blurb="Edition V1 (safe modes era, md5/sha256 probes)"),
    ("metadata-driven", 2): dict(
        keywords=MD_EPOCHS[2], modifiers=False, fallbacks=False,
        options=set(), modes=MD_MODES, icons=False,
        blurb="Edition V2 (full hash epoch, dependency self-check)"),
    ("metadata-driven", 3): dict(
        keywords=MD_EPOCHS[3], modifiers=False, fallbacks=False,
        options=set(), modes=MD_MODES, icons=False,
        blurb="Edition V3 (Resolve_Template: multi-segment --dirs/--subdirs)"),
    ("metadata-driven", 4): dict(
        keywords=MD_EPOCHS[4], modifiers=False, fallbacks=False,
        options=set(), modes=MD_MODES, icons=False,
        blurb="Edition V4 (path/name/extension context-aware resolution)"),
    ("metadata-driven", 5): dict(
        keywords=MD_EPOCHS[5], modifiers=False, fallbacks=False,
        options=set(), modes=MD_MODES, icons=False,
        blurb="Edition V5 (extended keys: ext-lower, bytes)"),
    ("metadata-driven", 6): dict(
        keywords=MD_EPOCHS[6], modifiers=True, fallbacks=True,
        options={"jobs"}, modes=MD_MODES, icons=False,
        blurb="Edition V6 (Resolve_Value: lower:/upper:/raw: prefixes, "
              "first-match fallbacks k1|k2|k3)"),
    # Media-Intelligent line
    ("media-intelligent", 1): dict(
        keywords=MI_EPOCHS[1], modifiers=False, fallbacks=False,
        options=set(), modes=MI_MODES, icons=False,
        blurb="Edition V1 (v2.2 rev 1)"),
    ("media-intelligent", 2): dict(
        keywords=MI_EPOCHS[2], modifiers=False, fallbacks=False,
        options=set(), modes=MI_MODES, icons=False,
        cleanup=True,
        blurb="Edition V2 (v2.2 rev 2: Remove_Empty_Source_Directory)"),
    ("media-intelligent", 3): dict(
        keywords=MI_EPOCHS[3], modifiers=False, fallbacks=False,
        options=set(), modes=MI_MODES, icons=True,
        cleanup=True,
        blurb="Edition V3 (v2.2 rev 3: emoji status icons)"),
    ("media-intelligent", 4): dict(
        keywords=MI_EPOCHS[4], modifiers=False, fallbacks=False,
        options={"jobs"}, modes=MI_MODES, icons=True,
        cleanup=True,
        blurb="Edition V4 (v3.0: threaded pool, dry-run default)"),
    ("media-intelligent", 5): dict(
        keywords=MI_EPOCHS[5], modifiers=False, fallbacks=False,
        options={"jobs", "pause"}, modes=MI_MODES, icons=True,
        cleanup=True,
        blurb="Edition V5 (v3.1: heavily documented stable generation)"),
    ("media-intelligent", 6): dict(
        keywords=MI_EPOCHS[6], modifiers=False, fallbacks=False,
        options={"jobs", "pause", "log"}, modes=MI_MODES, icons=True,
        cleanup=True,
        blurb="Edition V6 (v5.1: threads, live action log, display)"),
    ("media-intelligent", 7): dict(
        keywords=MI_EPOCHS[7], modifiers=True, fallbacks=True,
        options={"jobs", "pause", "log"}, modes=MI_MODES, icons=True,
        cleanup=True,
        blurb="Edition V7 (v6: tag era - EXIF and ID3 parsed natively, "
              "plus the full template language)"),
}


def keywords_for(line: str, era: int) -> set:
    return set(ERAS[(line, era)]["keywords"])


# ---------------------------------------------------------------------------
# Validation + runner
# ---------------------------------------------------------------------------

TOKEN_RE = re.compile(r"(?:lower:|upper:|raw:)?([a-z0-9][a-z0-9+._-]*)")
SPEC_FLAGS = ("--dirs", "--subdirs", "--rename", "--extension")


def _spec_value(argv, flag):
    for i, tok in enumerate(argv):
        if tok.split("=", 1)[0] == flag:
            if "=" in tok:
                return tok.split("=", 1)[1]
            if i + 1 < len(argv):
                return argv[i + 1]
    return ""


def analyze_spec(spec: str):
    """Return (keywords, has_modifier, has_fallback)."""
    kws, mod, fb = set(), False, False
    for segment in (spec or "").split("/"):
        if "|" in segment:
            fb = True
        for cand in segment.split("|"):
            c = cand.strip().lower()
            if c.startswith(("lower:", "upper:", "raw:")):
                mod = True
            m = TOKEN_RE.match(c)
            if m:
                kws.add(m.group(1))
    return kws, mod, fb


def _fail(msg: str) -> int:
    print(msg)
    return 64


def run(argv, line: str, era: int) -> int:
    """Gate the era's capability set, then delegate to the engine."""
    cfg = ERAS[(line, era)]
    allowed = set(cfg["keywords"])

    # -- options of later eras
    gate = [("--jobs", "jobs"), ("--pause", "pause"), ("--log", "log")]
    for flag, feature in gate:
        if feature not in cfg["options"] and any(
                tok == flag or tok.startswith(flag + "=") for tok in argv):
            return _fail(f"{flag} is not part of the {cfg['blurb']} "
                         f"feature scope.")

    # -- modes
    argv = list(argv)
    i = 0
    while i < len(argv):
        if argv[i].startswith("--mode"):
            val = (argv[i].split("=", 1) + [""])[1] if "=" in argv[i] else \
                (argv[i + 1] if i + 1 < len(argv) else "")
            if not val and i + 1 < len(argv) and not argv[i + 1].startswith("-"):
                val = argv[i + 1]
            if val and val not in cfg["modes"]:
                return _fail(f"--mode={val} is not available in this edition. "
                             f"Modes: {', '.join(sorted(cfg['modes']))}")
            break
        i += 1

    # -- template keyword scope
    for flag in SPEC_FLAGS:
        spec = _spec_value(argv, flag)
        kws, mod, fb = analyze_spec(spec)
        bad = kws - allowed
        if bad:
            return _fail(f"keyword(s) not available in this edition for "
                         f"{flag}: {', '.join(sorted(bad))}. Available: "
                         f"{', '.join(sorted(allowed))}")
        if mod and not cfg["modifiers"]:
            return _fail(f"lower:/upper:/raw: modifiers are not part of "
                         f"the {cfg['blurb']} scope.")
        if fb and not cfg["fallbacks"]:
            return _fail(f"fallback syntax (k1|k2) is not part of "
                         f"the {cfg['blurb']} scope.")

    # era default: icons off before the icon epoch when not overridden
    if not cfg["icons"] and not any(
            tok in ("--icons", "--no-icons") for tok in argv):
        argv = list(argv) + ["--no-icons"]

    return ENGINE.main(argv)
