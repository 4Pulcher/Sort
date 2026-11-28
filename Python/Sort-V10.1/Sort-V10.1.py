#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sort.py - Media-Intelligent File Organizer (Python edition)
===========================================================

A pure-Python (standard library only) implementation of the complete Bash
`Sort.sh` lineage (V1.0 -> V17.3), designed to match the feature union of the
whole family with ZERO external dependencies:

* no `file`, no ImageMagick, no FFmpeg, no ExifTool, no GNU coreutils calls:
  MIME sniffing, media dimensions, hashing and text detection are all native.

Feature chronology of the Bash lineage, unified in this file:

  V1.x-V4.x   core organize flow, MIME keywords, template destination paths
  V5.x        Media-Intelligent rename/spec engine (hash, size, format)
  V6.x        optimized single-file mode parsing, type filters
  V7-V8       source/target argument model, per-file templates
  V9.x        safe copy/move/remove modes, dry-run default, self-tests
  V10.x       v2.2+ explanatory revision, MIME main/sub model, icons
  V11.0       fully self-contained edition (the GitHub `Sort.sh`)
  V12.x       threaded worker pool, live logging, dry-run by default
  V13.x       heavy-commented stable generation
  V14-V15     Safe-Transport (freedesktop trash, shred) and undo-log era
  V16-V17     template language extensions:
               lower:/upper:/raw: value prefixes, first-match fallbacks (a|b|c),
               slugified names, self-test suite, undo replay

Requires: Python 3.9+ (Debian: `python3` package, main repo; nothing from
contrib/non-free, no pip packages).

Usage examples:
    Sort.py                                    # help / man page
    Sort.py --dirs=mime-main --type=image Downloads/*
    Sort.py --mode=move --dirs=year+month --type=video Videos/
    Sort.py --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg
    Sort.py --mode=trash --recursive --type=archive Downloads/
    Sort.py --log actions.jsonl --mode=move ...
    Sort.py --undo actions.jsonl               # reverse logged actions

Safety: like the Bash lineage, with no --mode the script performs a DRY RUN.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime
import hashlib
import json
import mimetypes
import os
import re
import shutil
import struct
import sys
import tempfile
import time
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

__version__ = "py-17.3"          # corresponds to the latest Bash edition
LINEAGE_NOTE = "Python port of the Sort.sh V1.0-V17.3 lineage (stdlib only)"

# ===========================================================================
# 1. UI: COLORS, ICONS, INTERNATIONALIZATION
# ===========================================================================

ICONS = {
    "info": "\u2139\ufe0f", "ok": "\u2705", "warn": "\u26a0\ufe0f",
    "error": "\u274c", "skip": "\u23ed\ufe0f", "dir": "\U0001f4c1",
    "file": "\U0001f4c4", "link": "\U0001f517", "copy": "\U0001f4cb",
    "move": "\U0001f69a", "remove": "\U0001f5d1\ufe0f", "mime": "\U0001f3f7",
    "target": "\U0001f3af", "name": "\U0001f4dd", "hash": "\U0001f511",
    "clean": "\U0001f9f9", "done": "\U0001f3c1", "test": "\U0001f9ea",
}

TRANSLATIONS = {
    "en": {
        "start": "Starting action:", "dry": "DRY RUN - no changes made",
        "target": "Target", "mode": "Mode", "files": "files processed",
        "copied": "copied", "moved": "moved", "removed": "removed",
        "trashed": "trashed", "shredded": "shredded", "skipped": "skipped",
        "failed": "failed", "empty": "empty directory removed: ",
        "done": "Complete", "notfound": "Path not found: ",
        "filtered": "filtered by type: ",
        "confirm": "Action: [C]ancel, [S]kip, Skip [A]ll, [R]eplace, Replace a[L]l: ",
        "noinput": "No input files or directories provided.",
    },
    "nl": {
        "start": "Actie gestart:", "dry": "TESTMODUS - geen wijzigingen doorgevoerd",
        "target": "Doel", "mode": "Modus", "files": "bestanden verwerkt",
        "copied": "gekopieerd", "moved": "verplaatst", "removed": "verwijderd",
        "trashed": "naar prullenbak", "shredded": "vernietigd", "skipped": "overgeslagen",
        "failed": "mislukt", "empty": "lege map verwijderd: ",
        "done": "Klaar", "notfound": "Pad niet gevonden: ",
        "filtered": "gefilterd op type: ",
        "confirm": "Actie: [A]nnuleren, [O]verslaan, Overslaan a[L]le, [V]ervangen, Vervangen a[L]le: ",
        "noinput": "Geen invoerbestanden of mappen opgegeven.",
    },
    "fr": {
        "start": "Action commencée :", "dry": "SIMULATION - aucun changement effectué",
        "target": "Cible", "mode": "Mode", "files": "fichiers traités",
        "copied": "copiés", "moved": "déplacés", "removed": "supprimés",
        "trashed": "à la corbeille", "shredded": "détruits", "skipped": "ignorés",
        "failed": "échoués", "empty": "répertoire vide supprimé : ",
        "done": "Terminé", "notfound": "Chemin introuvable : ",
        "filtered": "filtré par type : ",
        "confirm": "Action : [A]nnuler, [I]gnorer, Ignorer [T]out, [R]emplacer, Remplacer [T]out : ",
        "noinput": "Aucun fichier ou répertoire fourni.",
    },
    "de": {
        "start": "Aktion gestartet:", "dry": "TESTLAUF - keine Änderungen durchgeführt",
        "target": "Ziel", "mode": "Modus", "files": "Dateien verarbeitet",
        "copied": "kopiert", "moved": "verschoben", "removed": "gelöscht",
        "trashed": "in den Papierkorb", "shredded": "vernichtet", "skipped": "übersprungen",
        "failed": "fehlgeschlagen", "empty": "leeres Verzeichnis entfernt: ",
        "done": "Fertig", "notfound": "Pfad nicht gefunden: ",
        "filtered": "nach Typ gefiltert: ",
        "confirm": "Aktion: [A]bbrechen, [Ü]berspringen, Überspringen a[L]le, [E]rsetzen, Ersetzen a[L]le: ",
        "noinput": "Keine Eingabedateien oder -verzeichnisse angegeben.",
    },
    "tr": {
        "start": "Eylem başladı:", "dry": "KURU ÇALIŞMA - değişiklik yapılmadı",
        "target": "Hedef", "mode": "Mod", "files": "dosya işlendi",
        "copied": "kopyalandı", "moved": "taşındı", "removed": "silindi",
        "trashed": "çöpe atıldı", "shredded": "imha edildi", "skipped": "atlandı",
        "failed": "başarısız", "empty": "boş klasör kaldırıldı: ",
        "done": "Tamamlandı", "notfound": "Yol bulunamadı: ",
        "filtered": "türe göre filtrelendi: ",
        "confirm": "Eylem: [İ]ptal, [A]tla, Atla [H]epsi, [D]eğiştir, Değiştir [H]epsi: ",
        "noinput": "Girdi dosyası veya dizin verilmedi.",
    },
}
# NOTE: V17.1 of the Bash lineage shipped 20 UI languages; this port keeps the
# translation table compact (en, nl, fr, de, tr) and trivially extensible.


class UI:
    """Terminal output: colors (V2.2+), icons (V10.3), translations (V17.1)."""

    def __init__(self, colors: bool = True, icons: bool = True,
                 lang: str = "en", quiet: bool = False):
        self.on = colors and sys.stdout.isatty()
        self.icons = icons
        self.quiet = quiet
        self.t = TRANSLATIONS.get(lang, TRANSLATIONS["en"])

    def _c(self, code: str, text: str) -> str:
        return f"\033[{code}m{text}\033[0m" if self.on else text

    def icon(self, key: str) -> str:
        return (ICONS.get(key, "") + " ") if self.icons else ""

    def bold(self, t): return self._c("1", t)
    def info(self, t): return self._c("36", t)
    def ok(self, t): return self._c("32", t)
    def warn(self, t): return self._c("33", t)
    def err(self, t): return self._c("31", t)
    def label(self, t): return self._c("94", t)
    def dim(self, t): return self._c("2", t)
    def path(self, t): return self._c("37", t)

    def say(self, msg: str) -> None:
        if not self.quiet:
            print(msg)

    def T(self, key: str) -> str:
        return self.t[key]


# ===========================================================================
# 2. MIME SNIFFING (native magic-byte engine - Pascal FindMime heritage)
# ===========================================================================

# (offset, magic bytes) -> (mime-main, mime-sub)
BINARY_SIGNATURES = [
    (0, b"\x89PNG\r\n\x1a\n", ("image", "png")),
    (0, b"\xff\xd8\xff", ("image", "jpeg")),
    (0, b"GIF87a", ("image", "gif")),
    (0, b"GIF89a", ("image", "gif")),
    (0, b"BM", ("image", "bmp")),
    (0, b"II*\x00", ("image", "tiff")),
    (0, b"MM\x00*", ("image", "tiff")),
    (0, b"\x1f\x8b", ("archive", "gzip")),
    (0, b"BZh", ("archive", "bzip2")),
    (0, b"\xfd7zXZ\x00", ("archive", "xz")),
    (0, b"7z\xbc\xaf\x27\x1c", ("archive", "7z")),
    (0, b"Rar!\x1a\x07", ("archive", "rar")),
    (0, b"%PDF", ("document", "pdf")),
    (0, b"{\\rtf", ("document", "rtf")),
    (0, b"\x7fELF", ("binary", "elf")),
    (0, b"MZ", ("binary", "exe")),
    (0, b"\xca\xfe\xba\xbe", ("binary", "java-class")),
    (0, b"FLV\x01", ("video", "flv")),
    (4, b"ftypisom", ("video", "mp4")),
    (4, b"ftypmp4", ("video", "mp4")),
    (4, b"ftypavc1", ("video", "mp4")),
    (4, b"ftypisd ", ("video", "mp4")),
    (4, b"ftypM4A ", ("audio", "mp4a")),
    (4, b"ftypqt  ", ("video", "quicktime")),
    (0, b".snd", ("audio", "au")),
    (0, b"ID3", ("audio", "mpeg")),
    (0, b"\xff\xfb", ("audio", "mpeg")),
    (0, b"\xff\xf3", ("audio", "mpeg")),
    (0, b"\xff\xf2", ("audio", "mpeg")),
    (0, b"OggS", ("audio", "ogg")),
    (0, b"fLaC", ("audio", "flac")),
    (0, b"RIFF", ("audio", "wav")),   # refined below by container tag
    (0, b"PK\x03\x04", ("archive", "zip")),
    (0, b"PK\x05\x06", ("archive", "zip")),   # empty zip (EOCD only)
    (0, b"PK\x07\x08", ("archive", "zip")),   # spanned zip
]

TEXT_SNIFFERS = [
    (re.compile(rb"^\s*\{"), "json"),
    (re.compile(rb"<\?xml"), "xml"),
    (re.compile(rb"<!DOCTYPE HTML|<html", re.I), "html"),
    (re.compile(rb"^---\s*$", re.M), "yaml"),
    (re.compile(rb"#!/bin/(ba)?sh|#!/usr/bin/env (ba)?sh|#!/bin/dash"), "x-shellscript"),
    (re.compile(rb"^#!.*python"), "x-python"),
]


def sniff_mime(path: Path, head: bytes | None = None) -> tuple[str, str]:
    """Return (mime-main, mime-sub) using magic bytes then heuristics."""
    try:
        if head is None:
            with open(path, "rb") as f:
                head = f.read(512)
    except OSError:
        return ("unknown", "unknown")
    if not head:
        return ("empty", "empty")

    hit = None
    for off, magic, mime in BINARY_SIGNATURES:
        if head[off:off + len(magic)] == magic:
            hit = mime
            break

    if hit:
        # container refinements
        if head.startswith(b"RIFF"):
            if head[8:12] == b"WAVE":
                return ("audio", "wav")
            if head[8:12] == b"AVI ":
                return ("video", "avi")
            if head[8:12] == b"WEBP":
                return ("image", "webp")
            return hit
        if head.startswith(b"\x1aE\xdf\xa3"):
            if b"webm" in head[:64]:
                return ("video", "webm")
            return ("video", "matroska")
        if head.startswith(b"PK\x03\x04"):
            return ("archive", "zip")
        return hit

    # binary oracle failed: text heuristics (Pascal SniffTextMime heritage)
    sample = head[:512]
    sample = bytes(ch for ch in sample if ch in (9, 10, 13) or 32 <= ch < 127 or ch >= 128)
    if all(32 <= b < 127 or b in (9, 10, 13) for b in head[:256]) or head[:1] in (b"\n", b"\r", b" ", b"\t"):
        for rx, sub in TEXT_SNIFFERS:
            if rx.search(sample):
                return ("text", sub)
        return ("text", "plain")

    # fall back to python-mimetypes by extension (stdlib)
    guessed, _ = mimetypes.guess_type(path.name)
    if guessed and "/" in guessed:
        main, _, sub = guessed.partition("/")
        return (main, sub or "unknown")
    return ("binary", "unknown")


# ===========================================================================
# 3. MEDIA DIMENSIONS (native PNG/GIF/BMP/JPEG/WEBP parsing)
# ===========================================================================


def image_dimensions(path: Path) -> tuple[int, int] | None:
    """Parse WxH natively for PNG, GIF, BMP, JPEG, WEBP. No ImageMagick."""
    f = None
    try:
        size = path.stat().st_size
        f = open(path, "rb")
        head = f.read(64)
        if size < 8:
            return None
        if head.startswith(b"\x89PNG") and size >= 24:
            w, h = struct.unpack(">II", head[16:24])
            return (w, h)
        if head[:6] in (b"GIF87a", b"GIF89a"):
            w, h = struct.unpack("<HH", head[6:10])
            return (w, h)
        if head.startswith(b"BM") and size > 26:
            w, h = struct.unpack("<ii", head[18:26])
            return (abs(w), abs(h))
        if head.startswith(b"RIFF") and head[8:12] == b"WEBP":
            if head[12:16] == b"VP8X":
                w = int.from_bytes(head[24:27], "little") + 1
                h = int.from_bytes(head[27:30], "little") + 1
                return (w, h)
            if head[12:16] == b"VP8 ":
                f.seek(26)
                w, h = struct.unpack("<HH", f.read(4))
                return (w, h)
            if head[12:16] == b"VP8L":
                bits = int.from_bytes(head[21:25], "little")
                return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
        if head.startswith(b"\xff\xd8\xff"):
            f.seek(2)
            while True:
                marker = f.read(2)
                if len(marker) < 2:
                    return None
                if marker[0] != 0xFF:
                    return None
                code = marker[1]
                if code == 0xD8 or code == 0x01 or 0xD0 <= code <= 0xD7:
                    continue  # standalone markers
                seglen_bytes = f.read(2)
                if len(seglen_bytes) < 2:
                    return None
                seglen = int.from_bytes(seglen_bytes, "big")
                if code in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6,
                            0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    data = f.read(5)
                    h, w = struct.unpack(">HH", data[1:5])
                    return (w, h)
                f.seek(seglen - 2, 1)
    except (OSError, struct.error):
        return None
    finally:
        if f:
            f.close()
    return None


RESOLUTION_TIERS = [
    (240, "TINY"), (360, "MINI"), (480, "SMALLER"), (600, "SMALL"),
    (900, "MEDIUM"), (1280, "BIG"), (1920, "BIGGER"), (1 << 30, "HUGE"),
]


def resolution_format_label(w: int, h: int) -> str:
    """V2.2 style resolution labels: tier + orientation."""
    if w <= 0 or h <= 0:
        return "ZERO"
    edge = max(w, h)
    tier = next(name for lim, name in RESOLUTION_TIERS if edge <= lim)
    orientation = "SQUARE" if w == h else ("WIDE" if w > h else "HIGH")
    return f"{tier}-{orientation}"


def decimal_size_label(num_bytes: int, unit: str = "size") -> str:
    """V2.2 style size tokens: e.g. '15-Mega' (format) / '15MB' (size)."""
    n = int(num_bytes or 0)
    divs = {"Tera": 1000**4, "Giga": 1000**3, "Mega": 1000**2,
            "Kilo": 1000, "Byte": 1}
    sizes = {"TB": 1000**4, "GB": 1000**3, "MB": 1000**2, "KB": 1000, "B": 1}
    if unit.startswith("format"):
        for name, div in divs.items():
            q = n // div
            if q > 0:
                return f"{q}-{name}"
        return "0-Byte"
    for name, div in sizes.items():
        q = n // div
        if q >= 1:
            return f"{q}{name}"
    return "0B"


# ===========================================================================
# 4. HASHING (V5.x heritage: checksum keywords)
# ===========================================================================

HASH_ALGOS = {"md5sum": "md5", "sha1sum": "sha1", "sha224sum": "sha224",
              "sha256sum": "sha256", "sha384sum": "sha384", "sha512sum": "sha512"}


def hash_file(path: Path, algo_key: str) -> str:
    h = hashlib.new(HASH_ALGOS.get(algo_key, algo_key.replace("sum", "") or "md5"))
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ===========================================================================
# 5. FILE METADATA (V2.x getters, unified into one record)
# ===========================================================================


@dataclass
class FileFacts:
    """All per-file facts the template engine can reference."""
    path: Path
    mime_main: str
    mime_sub: str
    size: int = 0
    dims: tuple[int, int] | None = None
    created: datetime.datetime = field(default_factory=datetime.datetime.now)
    modified: datetime.datetime = field(default_factory=datetime.datetime.now)
    accessed: datetime.datetime = field(default_factory=datetime.datetime.now)
    hashes: dict = field(default_factory=dict)

    @property
    def name(self) -> str:
        return self.path.name

    @property
    def stem(self) -> str:
        return self.path.stem

    @property
    def ext(self) -> str:
        return self.path.suffix.lstrip(".")


def gather_facts(path: Path, want_hashes: set) -> FileFacts:
    main, sub = sniff_mime(path)
    st = path.stat()
    b = getattr(st, "st_birthtime", None) or st.st_mtime
    facts = FileFacts(
        path=path, mime_main=main, mime_sub=sub, size=st.st_size,
        created=datetime.datetime.fromtimestamp(b),
        modified=datetime.datetime.fromtimestamp(st.st_mtime),
        accessed=datetime.datetime.fromtimestamp(st.st_atime),
    )
    if main == "image" or sub in ("webm", "mp4", "avi", "quicktime", "matroska"):
        facts.dims = image_dimensions(path)
    for kw in want_hashes:
        if path.is_file() and path.stat().st_size:
            facts.hashes[kw] = hash_file(path, kw)
    return facts


# ===========================================================================
# 6. TEMPLATE ENGINE (V9 Resolve_Value + V17 prefix/fallback language)
# ===========================================================================


def slugify(text: str) -> str:
    """Slug used for path segments (V17)."""
    text = unicodedata.normalize("NFKD", text)
    kept = "".join(ch if (ch.isalnum() or ch in "-_.") else "-" for ch in text)
    kept = re.sub(r"-+", "-", kept).strip("-")
    return kept


class TemplateEngine:
    """
    Parses --dirs / --subdirs / --rename / --extension specifications.

    Keywords (union of the Bash lineage):
      year, month, day, year+month, year+month+day,
      created, modified, accessed (+/-date/-time variants),
      mime, mime-main, mime-sub, type,
      extension, ext, ext-lower, ext-upper, filename, name, basename, stem,
      original, size, format, size+format, pixel-size, pixel-format,
      md5sum, sha1sum, sha224sum, sha256sum, sha384sum, sha512sum, random

    Modifiers (V17): lower:KEY, upper:KEY, raw:KEY
    Fallbacks (V17): KEY1|KEY2|KEY3  (first non-empty wins)
    Segments joined with '/' for path context, '_' for name context.
    """

    def __init__(self, spec: str, context: str = "path", random_tag_var: str = ""):
        self.spec = spec or ""
        self.context = context  # path | name | extension
        self.random_value = random_tag_var

    def keyword_value(self, facts: FileFacts, kw: str) -> str:
        d = {"created": facts.created, "modified": facts.modified,
             "accessed": facts.accessed}
        if kw in d:
            return d[kw].strftime("%Y-%m-%d-%H-%M-%S")
        if kw in ("created-time", "modified-time", "accessed-time"):
            return d[kw.split("-")[0]].strftime("%H-%M-%S")
        if kw in ("created-date", "modified-date", "accessed-date"):
            return d[kw.split("-")[0]].strftime("%Y-%m-%d")
        if kw == "year":
            return facts.modified.strftime("%Y")
        if kw == "month":
            return facts.modified.strftime("%m")
        if kw == "day":
            return facts.modified.strftime("%d")
        if kw == "year+month":
            return facts.modified.strftime("%Y-%m")
        if kw == "year+month+day":
            return facts.modified.strftime("%Y-%m-%d")
        if kw in ("mime", "mime-main", "mimemain", "type"):
            return facts.mime_main
        if kw == "mime-sub":
            return facts.mime_sub
        if kw in ("extension", "ext"):
            return facts.ext or "NOEXT"
        if kw == "ext-lower":
            return (facts.ext or "noext").lower()
        if kw == "ext-upper":
            return (facts.ext or "NOEXT").upper()
        if kw in ("filename", "name", "basename"):
            return facts.name
        if kw in ("stem", "original"):
            return facts.stem
        if kw == "size":
            return decimal_size_label(facts.size, "size")
        if kw == "format":
            return decimal_size_label(facts.size, "format")
        if kw == "size+format":
            return (decimal_size_label(facts.size, "size") + "-" +
                    decimal_size_label(facts.size, "format"))
        if kw in ("pixel-size", "resolution", "dims"):
            return f"{facts.dims[0]}x{facts.dims[1]}" if facts.dims else "0x0"
        if kw in ("pixel-format", "resolution-format"):
            return resolution_format_label(*facts.dims) if facts.dims else "ZERO"
        if kw in HASH_ALGOS:
            return facts.hashes.get(kw, "")
        if kw == "random":
            return self.random_value
        return ""

    def segment(self, facts: FileFacts, seg: str) -> str:
        """Resolve one template segment with prefixes and fallbacks."""
        value_style = "default"
        expr = seg.strip()
        while True:                                   # lower:/upper:/raw:
            low = expr.lower()
            if low.startswith("lower:"):
                expr, value_style = expr[6:], "lower"
            elif low.startswith("upper:"):
                expr, value_style = expr[6:], "upper"
            elif low.startswith("raw:"):
                expr, value_style = expr[4:], "raw"
            else:
                break
        candidates = [c.strip() for c in expr.split("|")] if "|" in expr else [expr]
        raw_value = ""
        for cand in candidates:
            if not cand:
                continue
            val = self.keyword_value(facts, cand)
            if val:
                raw_value = val
                break
        if not raw_value:
            return ""
        if value_style == "raw":
            return raw_value
        if self.context == "path":
            out = slugify(raw_value).upper()
        elif self.context == "name":
            out = slugify(raw_value)
        else:                                   # extension: trimmed only
            out = raw_value
        if value_style == "lower":
            out = out.lower()
        elif value_style == "upper":
            out = out.upper()
        return out

    def resolve(self, facts: FileFacts) -> str:
        """Resolve the full spec; path context joins with '/', name with '_'."""
        if not self.spec:
            return ""
        segs = [s for s in (seg.strip() for seg in self.spec.split("/")) if s]
        resolved = [self.segment(facts, s) for s in segs]
        resolved = [r for r in resolved if r]
        joiner = "/" if self.context == "path" else "_"
        return joiner.join(resolved)


# ===========================================================================
# 7. MODES: DUMMY / COPY / MOVE / REMOVE / TRASH / SHRED (V14 Safe Transport)
# ===========================================================================


def freedesktop_trash(path: Path, ui: UI) -> str:
    """Move a file into the XDG trash with a .trashinfo entry (stdlib only)."""
    trash_root = Path(os.environ.get("XDG_DATA_HOME",
                                     Path.home() / ".local/share")) / "Trash"
    files_dir = trash_root / "files"
    info_dir = trash_root / "info"
    files_dir.mkdir(parents=True, exist_ok=True)
    info_dir.mkdir(parents=True, exist_ok=True)
    dest = files_dir / path.name
    i = 1
    while dest.exists():
        dest = files_dir / f"{path.stem}-{i}{path.suffix}"
        i += 1
    shutil.move(str(path), str(dest))
    deletion = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    info = f"[Trash Info]\nPath={path.resolve()}\nDeletionDate={deletion}\n"
    (info_dir / f"{dest.name}.trashinfo").write_text(info, encoding="utf-8")
    ui.say(f"{ui.icon('remove')}{ui.ok(ui.T('trashed'))} "
           f"{ui.path(str(path))} -> {ui.path(str(dest))}")
    return str(dest)


def shred_file(path: Path, ui: UI, passes: int = 3) -> None:
    """Best-effort secure overwrite (V14). No warranty on SSD/COW volumes."""
    size = path.stat().st_size
    with open(path, "ba+") as f:
        for _ in range(passes):
            f.seek(0)
            f.write(os.urandom(size))
            f.flush()
            os.fsync(f.fileno())
    os.remove(path)
    ui.say(f"{ui.icon('remove')}{ui.err(ui.T('shredded'))} {ui.path(str(path))}")


# ===========================================================================
# 8. CORE ENGINE (V6.x heritage: parse -> filter -> resolve -> act)
# ===========================================================================

TYPE_FILTERS = {
    "image": {"image"}, "video": {"video"}, "audio": {"audio"},
    "document": {"document", "text"}, "doc": {"document", "text"},
    "archive": {"archive"}, "text": {"text"}, "binary": {"binary"},
}


@dataclass
class Options:
    mode: str = "dummy"
    dirs: str = ""
    subdirs: str = ""
    rename: str = ""
    extension: str = ""
    type_filter: str = ""
    target: Path | None = None
    inputs: list = field(default_factory=list)
    recursive: bool = False
    hidden: bool = False
    follow_links: bool = False
    replace: str = "ask"            # ask | always | never
    pause: float = 0.0
    jobs: int = 1
    log: Path | None = None
    cleanup_empty: bool = True
    lang: str = "en"
    colors: bool = True
    icons: bool = True
    quiet: bool = False


class Organizer:
    def __init__(self, opts: Options):
        self.opts = opts
        self.ui = UI(opts.colors, opts.icons, opts.lang, opts.quiet)
        self.counters = {"copied": 0, "moved": 0, "removed": 0, "trashed": 0,
                         "shredded": 0, "skipped": 0, "failed": 0, "filtered": 0}
        self.log_fh = open(opts.log, "a", encoding="utf-8") if opts.log else None
        self.skip_all = False
        self.replace_all = False
        self._hashes_wanted = self._scan_hash_keywords()

    # ---- keyword requirements discovered from the specs -------------------
    def _scan_hash_keywords(self) -> set:
        wanted = set()
        for spec in (self.opts.dirs, self.opts.subdirs,
                     self.opts.rename, self.opts.extension):
            for kw in re.findall(r"(?:lower:|upper:|raw:)?([a-z0-9+_-]+)",
                                 spec or ""):
                if kw in HASH_ALGOS:
                    wanted.add(kw)
        return wanted

    # ---- input collection ---------------------------------------------------
    def collect(self) -> list:
        found: list = []
        for item in self.opts.inputs:
            p = Path(item)
            if not p.exists() and not p.is_symlink():
                self.ui.say(f"{self.ui.icon('warn')}{self.ui.err(self.ui.T('notfound'))} "
                            f"{self.ui.path(str(p))}")
                continue
            if p.is_dir():
                if self.opts.recursive:
                    for root, dirnames, filenames in os.walk(
                            p, followlinks=self.opts.follow_links):
                        dirnames[:] = [d for d in dirnames
                                       if self.opts.hidden or not d.startswith(".")]
                        for fn in filenames:
                            if not self.opts.hidden and fn.startswith("."):
                                continue
                            found.append(Path(root) / fn)
                else:
                    for entry in sorted(p.iterdir()):
                        if entry.is_file():
                            if not self.opts.hidden and entry.name.startswith("."):
                                continue
                            found.append(entry)
            else:
                found.append(p)
        seen, ordered = set(), []
        for f in found:
            key = str(f)
            if key not in seen:
                seen.add(key)
                ordered.append(f)
        return ordered

    # ---- type filter ----------------------------------------------------------
    def matches_filter(self, facts: FileFacts) -> bool:
        if not self.opts.type_filter:
            return True
        allowed = set()
        for part in self.opts.type_filter.split(","):
            allowed |= TYPE_FILTERS.get(part.strip().lower(), set())
        return facts.mime_main in allowed if allowed else True

    # ---- collision handling (V6.4 interactive) ---------------------------------
    def resolve_collision(self, src: Path, dst: Path) -> str:
        if not dst.exists():
            return "proceed"
        if self.replace_all or self.opts.replace == "always":
            return "replace"
        if self.skip_all or self.opts.replace == "never":
            return "skip"
        if not sys.stdin.isatty():
            return "skip"
        self.ui.say(f"{self.ui.icon('warn')}{self.ui.warn('collision:')} "
                    f"{self.ui.path(str(src))} -> {self.ui.path(str(dst))}")
        ans = input(self.ui.T("confirm")).strip().lower()
        if ans and ans[0] in ("r", "e", "d"):            # replace / ersetzen / degistir
            if "l" in ans or "t" in ans:
                self.replace_all = True
            return "replace"
        if ans and ans[0] in ("s", "o", "i", "a", "u"):
            if "l" in ans or "t" in ans:
                self.skip_all = True
            return "skip"
        return "cancel"

    # ---- action log (V15 undo heritage) ----------------------------------------
    def log_action(self, action: str, **kv) -> None:
        if self.log_fh:
            rec = {"time": datetime.datetime.now().isoformat(), "action": action}
            rec.update(kv)
            self.log_fh.write(json.dumps(rec) + "\n")
            self.log_fh.flush()

    # ---- per-file pipeline --------------------------------------------------------
    def process(self, path: Path) -> None:
        try:
            if not path.is_file() and not (path.is_symlink() and self.opts.follow_links):
                return
            facts = gather_facts(path, self._hashes_wanted)
            if not self.matches_filter(facts):
                self.counters["filtered"] += 1
                self.ui.say(f"{self.ui.icon('skip')}{self.ui.dim(self.ui.T('filtered'))} "
                            f"{self.ui.path(str(path))}")
                return
            target_root = self.opts.target or Path.cwd()
            tag = os.urandom(4).hex()
            rel_dir = TemplateEngine(self.opts.dirs, "path", tag).resolve(facts)
            rel_sub = TemplateEngine(self.opts.subdirs, "path", tag).resolve(facts)
            new_name = TemplateEngine(self.opts.rename, "name", tag).resolve(facts)
            new_ext = TemplateEngine(self.opts.extension, "extension", tag).resolve(facts)

            if self.opts.mode in ("remove", "trash", "shred"):
                destination = path
            else:
                folder = target_root / rel_dir if rel_dir else target_root
                if rel_sub:
                    folder = folder / rel_sub
                if self.opts.mode == "dummy":
                    name_disp = new_name if self.opts.rename else facts.name
                    ext_disp = ("." + new_ext) if self.opts.extension else \
                        (("." + facts.ext) if facts.ext else "")
                    destination = folder / (name_disp if self.opts.rename
                                            else facts.name + (ext_disp if self.opts.extension else ""))
                else:
                    stem = new_name if new_name else facts.stem
                    ext = ("." + new_ext) if new_ext else \
                        (("." + facts.ext) if facts.ext else "")
                    destination = folder / (stem + ext)
            self.act(path, facts, destination)
            if self.opts.pause > 0:
                time.sleep(self.opts.pause)
        except Exception as exc:                     # noqa: BLE001
            self.counters["failed"] += 1
            self.ui.say(f"{self.ui.icon('error')}{self.ui.err('ERROR:')} {exc} "
                        f"[{self.ui.path(str(path))}]")

    def act(self, path: Path, facts: FileFacts, destination: Path) -> None:
        ui, o = self.ui, self.opts
        if o.mode == "dummy":
            ui.say(f"{ui.icon('info')}{ui.dim(ui.T('dry'))} "
                   f"{ui.path(str(path))} -> {ui.path(str(destination))}")
            return
        if o.mode == "remove":
            path.unlink()
            self.counters["removed"] += 1
            self.log_action("removed", src=str(path))
            ui.say(f"{ui.icon('remove')}{ui.err(ui.T('removed'))} "
                   f"{ui.path(str(path))}")
            if o.cleanup_empty:
                self._cleanup_empty(path.parent, ui)
            return
        if o.mode == "trash":
            freedesktop_trash(path, ui)
            self.counters["trashed"] += 1
            self.log_action("trashed", src=str(path))
            return
        if o.mode == "shred":
            shred_file(path, ui)
            self.counters["shredded"] += 1
            self.log_action("shredded", src=str(path))
            return
        decision = self.resolve_collision(path, destination)
        if decision in ("skip", "cancel"):
            self.counters["skipped"] += 1
            return
        destination.parent.mkdir(parents=True, exist_ok=True)
        if o.mode == "copy":
            if decision == "replace" and destination.exists():
                destination.unlink()
            shutil.copy2(str(path), str(destination))
            self.counters["copied"] += 1
            self.log_action("copied", src=str(path), dst=str(destination))
            ui.say(f"{ui.icon('copy')}{ui.ok(ui.T('copied'))} "
                   f"{ui.path(str(path))} -> {ui.path(str(destination))}")
        elif o.mode == "move":
            if decision == "replace" and destination.exists():
                destination.unlink()
            shutil.move(str(path), str(destination))
            self.counters["moved"] += 1
            self.log_action("moved", src=str(path), dst=str(destination))
            ui.say(f"{ui.icon('move')}{ui.ok(ui.T('moved'))} "
                   f"{ui.path(str(path))} -> {ui.path(str(destination))}")
            if o.cleanup_empty:
                self._cleanup_empty(path.parent, ui)

    @staticmethod
    def _cleanup_empty(folder: Path, ui: UI) -> None:
        """V10.2 Remove_Empty_Source_Directory heritage."""
        try:
            if folder.is_dir() and not any(folder.iterdir()):
                folder.rmdir()
                ui.say(f"{ui.icon('clean')}{ui.info(ui.T('empty'))} "
                       f"{ui.path(str(folder))}")
        except OSError:
            pass

    # ---- top level ---------------------------------------------------------------
    def run(self) -> int:
        o = self.opts
        files = self.collect()
        if not files:
            ui = self.ui
            ui.say(ui.T("noinput"))
            return 30
        self.ui.say(f"{self.ui.icon('info')}{self.ui.bold(self.ui.T('start'))} "
                    f"{self.ui.label(o.mode)} | {self.ui.T('target')}: "
                    f"{self.ui.path(str(o.target or Path.cwd()))}")
        if o.mode == "dummy":
            self.ui.say(self.ui.dim(self.ui.T("dry")))
        if o.jobs > 1 and o.mode != "dummy":
            with concurrent.futures.ThreadPoolExecutor(max_workers=o.jobs) as pool:
                list(pool.map(self.process, files))
        else:
            for f in files:
                self.process(f)
        self.summary()
        if self.log_fh:
            self.log_fh.close()
        return 50 if self.counters["failed"] else 0

    def summary(self) -> None:
        ui = self.ui
        parts = [f"{v} {ui.T(k)}" for k, v in self.counters.items()
                 if k != "filtered" and v]
        ui.say(f"{ui.icon('done')}{ui.bold(ui.T('done'))}: "
               + (" | ".join(parts) if parts else "0 " + ui.T("files")))


# ===========================================================================
# 9. UNDO (V15 heritage: reverse a JSONL action log)
# ===========================================================================


def undo_log(logfile: Path) -> int:
    undone = 0
    for line in reversed(logfile.read_text(encoding="utf-8").splitlines()):
        if not line.strip():
            continue
        rec = json.loads(line)
        a = rec["action"]
        src, dst = rec.get("src", ""), rec.get("dst", "")
        try:
            if a == "moved" and dst and Path(dst).exists():
                Path(dst).parent.mkdir(parents=True, exist_ok=True)
                shutil.move(dst, src)
                undone += 1
            elif a == "copied" and dst and Path(dst).exists():
                Path(dst).unlink()
                undone += 1
            elif a == "trashed":
                trash_files = Path(os.environ.get(
                    "XDG_DATA_HOME", Path.home() / ".local/share")) / "Trash/files"
                cand = trash_files / Path(src).name
                if cand.exists():
                    shutil.move(str(cand), src)
                    undone += 1
            elif a == "removed":
                print(f"cannot restore removed file: {src}")
            elif a == "shredded":
                print(f"cannot restore shredded file: {src}")
        except (OSError, shutil.Error) as exc:
            print(f"undo failed: {exc}")
    print(f"Undone: {undone}")
    return 0


# ===========================================================================
# 10. SELF-TEST (V9.x / V16 heritage)
# ===========================================================================


def run_self_test() -> int:
    t = tempfile.mkdtemp(prefix="sort-py-selftest-")
    root = Path(t)
    passed = failed = 0

    def check(name: str, cond: bool, extra: str = "") -> None:
        nonlocal passed, failed
        if cond:
            passed += 1
            print(f"[PASS] {name} {extra}")
        else:
            failed += 1
            print(f"[FAIL] {name} {extra}")

    # fixtures
    png = root / "a.png"
    png.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" +
                    struct.pack(">II", 640, 480) + b"\x08\x06\x00\x00\x00")
    gif = root / "b.gif"
    gif.write_bytes(b"GIF89a" + struct.pack("<HH", 320, 200))
    jpeg = root / "c.jpg"
    jpeg.write_bytes(b"\xff\xd8\xff\xe0" + b"\x00\x10JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x00\x00" +
                     b"\xff\xc0\x00\x11\x08" + struct.pack(">HH", 600, 800) + b"\x03\x01\x22\x00")
    webp = root / "d.webp"
    webp.write_bytes(b"RIFF\x30\x00\x00\x00WEBPVP8X" + b"\x0a\x00\x00\x00" +
                     b"\x00\x00\x00\x00" + (1919).to_bytes(3, "little") +
                     (1079).to_bytes(3, "little"))
    pdf = root / "doc.pdf"
    pdf.write_bytes(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n1 0 obj\n<<>>\nendobj\ntrailer<<>>\n%%EOF")
    zipp = root / "arc.zip"
    zipp.write_bytes(b"PK\x03\x04" + b"\x14\x00\x00\x00\x08\x00" + b"\x00" * 64)
    mp3 = root / "song.mp3"
    mp3.write_bytes(b"ID3\x04\x00\x00\x00\x00\x00\x00" + b"\xff\xfb\x90\x44" + b"\x00" * 256)
    jsn = root / "data.json"
    jsn.write_text('{"a": 1}\n')
    shellf = root / "run.sh"
    shellf.write_text("#!/bin/sh\necho hi\n")
    txtf = root / "note.txt"
    txtf.write_text("just text\n")

    # MIME checks
    for f, expect in [(png, ("image", "png")), (gif, ("image", "gif")),
                      (jpeg, ("image", "jpeg")), (webp, ("image", "webp")),
                      (pdf, ("document", "pdf")), (zipp, ("archive", "zip")),
                      (mp3, ("audio", "mpeg")), (jsn, ("text", "json")),
                      (shellf, ("text", "x-shellscript")),
                      (txtf, ("text", "plain"))]:
        got = sniff_mime(f)
        check(f"mime {f.name}", got == expect, f"got={got}")

    # dimensions
    check("png dims", image_dimensions(png) == (640, 480), str(image_dimensions(png)))
    check("gif dims", image_dimensions(gif) == (320, 200), str(image_dimensions(gif)))
    check("jpeg dims", image_dimensions(jpeg) == (800, 600), str(image_dimensions(jpeg)))
    check("webp dims", image_dimensions(webp) == (1920, 1080), str(image_dimensions(webp)))

    # hashes
    check("md5", len(hash_file(png, "md5sum")) == 32)
    check("sha256", len(hash_file(png, "sha256sum")) == 64)

    # template engine
    facts = gather_facts(png, {"sha256sum"})
    got = TemplateEngine("mime-main/year+month/size", "path").resolve(facts)
    check("template path", bool(re.match(r"^IMAGE/\d{4}-\d{2}/\d+[KMGT]?B$", got)), got)
    eng3 = TemplateEngine("missing|mime-main", "extension")
    check("fallback", eng3.segment(facts, "missing|mime-main") == "image",
          eng3.segment(facts, "missing|mime-main"))
    eng4 = TemplateEngine("raw:filename", "name")
    check("raw prefix", eng4.segment(facts, "raw:filename") == "a.png",
          eng4.segment(facts, "raw:filename"))
    eng5 = TemplateEngine("year+month+day/pixel-format", "path")
    check("pixel-format", eng5.resolve(facts).count("/") == 1, eng5.resolve(facts))

    # organizer smoke test (copy with threads)
    src_dir = root / "in"
    src_dir.mkdir()
    (src_dir / "x.png").write_bytes(png.read_bytes())
    (src_dir / "y.pdf").write_bytes(pdf.read_bytes())
    (src_dir / "z.pdf").write_bytes(mpv := pdf.read_bytes())
    target = root / "out"
    opts = Options(mode="copy", dirs="mime-main", type_filter="image", target=target,
                  inputs=[src_dir], recursive=True, jobs=2, quiet=True, replace="always")
    org = Organizer(opts)
    rc = org.run()
    check("copy run", rc == 0)
    check("copy result", (target / "IMAGE" / "x.png").exists())

    # undo smoke test
    logf = root / "actions.jsonl"
    logf.write_text(json.dumps({"action": "copied", "src": str(src_dir / "x.png"),
                                "dst": str(target / "IMAGE" / "x.png")}) + "\n")
    before = (target / "IMAGE" / "x.png").exists()
    undo_log(logf)
    check("undo copy", before and not (target / "IMAGE" / "x.png").exists())

    print(f"\nPassed: {passed}  Failed: {failed}")
    shutil.rmtree(root, ignore_errors=True)
    return 2 if failed else 0


# ===========================================================================
# 11. CLI (mirrors the Bash Sort.sh argument model)
# ===========================================================================

MANPAGE = """Sort.py - Media-Intelligent File Organizer (Python edition, stdlib only)

MODES
  dummy (default)     dry run, prints intended destination for every file
  copy                copy files into the generated target tree
  move                move files, then remove source directories left empty
  remove              delete files outright (no trash) - use with care
  trash               freedesktop-standard move to the XDG trash
  shred               overwrite files 3x with random bytes, then delete

KEYWORD TEMPLATES  (--dirs, --subdirs, --rename, --extension)
  year, month, day, year+month, year+month+day
  created, modified, accessed  (and -date / -time variants)
  mime, mime-main, mime-sub, type
  extension, ext, ext-lower, ext-upper, filename, name, basename, stem, original
  size, format, size+format, pixel-size, pixel-format
  md5sum, sha1sum, sha224sum, sha256sum, sha384sum, sha512sum
  modifiers: lower:K  upper:K  raw:K     fallbacks: k1|k2|k3
  segments joined with '/' for dirs; '_' for names

EXAMPLES
  Sort.py --mode=dummy --dirs=mime-main --type=image Downloads/*
  Sort.py --mode=move --dirs=year+month --subdirs=pixel-format Videos/
  Sort.py --mode=copy --dirs=year --rename=sha256sum *.jpg
  Sort.py --mode=trash --recursive --type=archive Downloads/
  Sort.py --mode=move --log actions.jsonl --dirs=mime-main .
  Sort.py --undo actions.jsonl

NOTES
  Byte-sniffing is native: PNG/GIF/BMP/JPEG/WEBP dimensions, common media
  and archive magic numbers and text heuristics. External tools from the
  Bash editions (file, ffprobe, identify, exiftool) are intentionally NOT
  required. Requires only Python's standard library (Debian python3).
"""


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="Sort.py",
        description="Media-Intelligent File Organizer - "
                    "Python port of the Sort.sh lineage.",
        epilog=MANPAGE,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("inputs", nargs="*", help="files or directories to organize")
    p.add_argument("--mode", default="dummy",
                   choices=["dummy", "copy", "move", "remove", "trash", "shred"],
                   help="operation mode (default: dummy = dry run)")
    p.add_argument("--target", "-t", default=".", help="destination root")
    p.add_argument("--dirs", default="", help="template for the main folders")
    p.add_argument("--subdirs", default="", help="template for sub folders")
    p.add_argument("--rename", default="", help="template for the new file name")
    p.add_argument("--extension", default="",
                   help="template for the new extension")
    p.add_argument("--type", dest="type_filter", default="",
                   help="comma list: image,video,audio,document,archive,text,binary")
    p.add_argument("--recursive", action="store_true",
                   help="descend into directories")
    p.add_argument("--hidden", action="store_true", help="include dotfiles")
    p.add_argument("--links", action="store_true",
                   help="follow symbolic links")
    p.add_argument("--replace", default="ask",
                   choices=["ask", "always", "never"],
                   help="collision handling")
    p.add_argument("--pause", type=float, default=0.0,
                   help="seconds to pause between files")
    p.add_argument("--jobs", type=int, default=1,
                   help="parallel workers (V12)")
    p.add_argument("--log", default=None, help="JSONL action log (V15)")
    p.add_argument("--undo", default=None,
                   help="revert a JSONL action log (V15)")
    p.add_argument("--no-cleanup", dest="cleanup_empty", action="store_false",
                   help="keep directories left empty by move/remove")
    p.add_argument("--lang", default="en", choices=sorted(TRANSLATIONS),
                   help="UI language")
    p.add_argument("--no-colors", dest="colors", action="store_false")
    p.add_argument("--no-icons", dest="icons", action="store_false")
    p.add_argument("--quiet", action="store_true")
    p.add_argument("--version", action="version",
                   version=f"Sort.py {__version__} ({LINEAGE_NOTE})")
    p.add_argument("--self-test", action="store_true",
                   help="run the built-in test suite")
    return p


def main(argv: list | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()
    if args.undo:
        return undo_log(Path(args.undo))
    if not args.inputs:
        print(MANPAGE)
        return 0
    opts = Options(
        mode=args.mode, dirs=args.dirs, subdirs=args.subdirs, rename=args.rename,
        extension=args.extension, type_filter=args.type_filter,
        target=Path(args.target), inputs=args.inputs, recursive=args.recursive,
        hidden=args.hidden, follow_links=args.links, replace=args.replace,
        pause=args.pause, jobs=max(1, args.jobs),
        log=Path(args.log) if args.log else None,
        cleanup_empty=args.cleanup_empty, lang=args.lang, colors=args.colors,
        icons=args.icons, quiet=args.quiet,
    )
    return Organizer(opts).run()


# ===========================================================================
# EDITION GATE - auto-generated for Sort-V10.1
# Scope derived mechanically from Sort-V10.1.sh (era vocabulary).
# Run with --self-test to verify this engine, -h for the era usage.
# ===========================================================================

EDITION = {'version': 'V10.1', 'modes': ['copy', 'dummy', 'move', 'remove'], 'flags': ['--dirs', '--extension', '--hidden', '--links', '--pause', '--recursive', '--rename', '--replace', '--subdirs', '--type'], 'keywords': ['accessed', 'basename', 'created', 'day', 'ext', 'extension', 'filename', 'format', 'format+size', 'md5sum', 'mime', 'mime-main', 'mime-sub', 'modified', 'month', 'name', 'original', 'random', 'resolution', 'sha1sum', 'sha224sum', 'sha256sum', 'sha384sum', 'sha512sum', 'size', 'size+format', 'type', 'year', 'year+month', 'year+month+day'], 'modifiers': [], 'fallbacks': False, 'stripped': {'--title': 'metadata title rename (--title) - stripped', '--version': '--version'}}

CANONICAL_KEYWORDS = ["year", "month", "day", "year+month", "year+month+day", "created", "created-date", "created-time", "modified", "modified-date", "modified-time", "accessed", "accessed-date", "accessed-time", "mime", "mime-main", "mime-sub", "type", "extension", "ext", "ext-lower", "ext-upper", "filename", "name", "basename", "stem", "original", "size", "format", "size+format", "format+size", "pixel-size", "resolution", "pixel-format", "md5sum", "sha1sum", "sha224sum", "sha256sum", "sha384sum", "sha512sum", "random"]

_ERA_USAGE = """Sort-V10.1.py - standalone Python edition of Sort-V10.1.sh
(Standard library only; no external commands, no other files required.)

USAGE
    Sort-V10.1.py [OPTIONS] FILES...

MODES (--mode=...)
    copy, dummy, move, remove

OPTIONS
    --dirs, --extension, --hidden, --links, --pause, --recursive, --rename, --replace, --subdirs, --type, --mode, inputs

TEMPLATE KEYWORDS (for --dirs / --subdirs/--rename/--extension/--dirs)
    accessed, basename, created, day, ext, extension, filename, format, format+size, md5sum, mime, mime-main, mime-sub, modified, month, name, original, random, resolution, sha1sum, sha224sum, sha256sum, sha384sum, sha512sum, size, size+format, type, year, year+month, year+month+day
    (segments join with '/'; unknown words are literal folder text)

ALWAYS AVAILABLE
    -h / --help          this usage
    --self-test          engine self test
    --version            version banner

OUT OF SCOPE FOR THIS EDITION (stripped; see README.md)
    --title: metadata title rename (--title) - stripped; --version: --version
"""


def _era_error(msg):
    print("Sort-V10.1 edition error: " + msg)
    print("Allowed here -- modes: " + ", ".join(EDITION["modes"]) +
          " | flags: " + ", ".join(EDITION["flags"]) +
          " | keywords: " + ", ".join(EDITION["keywords"]))
    print("Run with -h for the full era usage.")
    return 64


def _check_template(value, arg):
    for seg in value.split("/"):
        for cand in seg.split("|"):
            expr = cand.strip()
            if not expr:
                continue
            while True:
                low = expr.lower()
                hit = next((p for p in ("lower:", "upper:", "raw:")
                            if low.startswith(p) and p[:-1] in EDITION["modifiers"]), None)
                if hit:
                    expr = expr[len(hit):]
                    continue
                break
            if "fallbacks" not in EDITION:
                continue
            kw = expr.strip().lower()
            if kw in CANONICAL_KEYWORDS and kw not in EDITION["keywords"]:
                raise SystemExit(_era_error(
                    "keyword '%s' is not part of Sort-%s (argument %s)" % (kw, EDITION["version"], arg)))


def _era_main(argv):
    allowed = set(EDITION["flags"]) | {"--self-test", "--version"}
    for a in argv:
        if a in ("-h", "--help"):
            print(_ERA_USAGE)
            return 0
        if a == "--self-test" or a == "--version" or not a.startswith("-"):
            continue
        name = a.split("=")[0].lower()
        if name == "--mode":
            val = a.split("=", 1)[1].lower() if "=" in a else ""
            if val and val not in EDITION["modes"]:
                raise SystemExit(_era_error(
                    "mode '%s' is not part of Sort-%s" % (val, EDITION["version"])))
            continue
        if name not in allowed:
            raise SystemExit(_era_error(
                "option '%s' is not part of Sort-%s" % (name, EDITION["version"])))
        if "=" in a and name in ("--dirs", "--subdirs", "--rename", "--extension"):
            _check_template(a.split("=", 1)[1], name)
    return main(argv)


if __name__ == "__main__":
    sys.exit(_era_main(sys.argv[1:]))
