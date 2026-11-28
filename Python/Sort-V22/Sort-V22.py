#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sort.py - Media-Intelligent File Organizer (Python edition)
===========================================================

A pure-Python (standard library only) implementation of the complete Bash
`Sort.sh` lineage (V1.0 -> V22), designed to match the feature union of the
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
import threading
import tempfile
import time
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

__version__ = "py-22"          # corresponds to the latest Bash edition
LINEAGE_NOTE = "Python port of the Sort.sh V1.0-V22 lineage (stdlib only)"

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


def hash_file_multi(path: Path, algo_keys) -> dict:
    """Read the file once and compute every requested algorithm in one pass."""
    digests = {kw: hashlib.new(HASH_ALGOS.get(kw, kw.replace("sum", "")) or "md5")
               for kw in algo_keys}
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            for d in digests.values():
                d.update(chunk)
    return {kw: d.hexdigest() for kw, d in digests.items()}


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
    if want_hashes and path.is_file() and st.st_size:
        facts.hashes.update(hash_file_multi(path, want_hashes))
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
        self.state_lock = threading.Lock()   # audit: shared counters need a lock
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
                with self.state_lock:
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

            # remove/trash/shred act on the calculated TARGET (Bash reference semantics)
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
            with self.state_lock:
                self.counters["failed"] += 1
            self.ui.say(f"{self.ui.icon('error')}{self.ui.err('ERROR:')} {exc} "
                        f"[{self.ui.path(str(path))}]")

    def act(self, path: Path, facts: FileFacts, destination: Path) -> None:
        ui, o = self.ui, self.opts
        if o.mode == "dummy":
            ui.say(f"{ui.icon('info')}{ui.dim(ui.T('dry'))} "
                   f"{ui.path(str(path))} -> {ui.path(str(destination))}")
            return
        if o.mode in ("remove", "trash", "shred"):
            # Bash reference semantics: act on the calculated TARGET, not the source
            if not destination.exists():
                with self.state_lock:
                    self.counters["failed"] += 1
                ui.say(f"{ui.icon('error')}{ui.err(ui.T('failed'))} "
                       f"{ui.path(str(path))} -> {ui.path(str(destination))}")
                return
        if o.mode == "remove":
            destination.unlink()
            with self.state_lock:
                self.counters["removed"] += 1
            self.log_action("removed", src=str(destination))
            ui.say(f"{ui.icon('remove')}{ui.err(ui.T('removed'))} "
                   f"{ui.path(str(destination))}")
            if o.cleanup_empty:
                self._cleanup_empty(destination.parent, ui)
            return
        if o.mode == "trash":
            freedesktop_trash(destination, ui)
            with self.state_lock:
                self.counters["trashed"] += 1
            self.log_action("trashed", src=str(destination))
            return
        if o.mode == "shred":
            shred_file(destination, ui)
            with self.state_lock:
                self.counters["shredded"] += 1
            self.log_action("shredded", src=str(destination))
            return
        decision = self.resolve_collision(path, destination)
        if decision in ("skip", "cancel"):
            with self.state_lock:
                self.counters["skipped"] += 1
            return
        destination.parent.mkdir(parents=True, exist_ok=True)
        if o.mode == "copy":
            if decision == "replace" and destination.exists():
                destination.unlink()
            shutil.copy2(str(path), str(destination))
            with self.state_lock:
                self.counters["copied"] += 1
            self.log_action("copied", src=str(path), dst=str(destination))
            ui.say(f"{ui.icon('copy')}{ui.ok(ui.T('copied'))} "
                   f"{ui.path(str(path))} -> {ui.path(str(destination))}")
        elif o.mode == "move":
            if decision == "replace" and destination.exists():
                destination.unlink()
            shutil.move(str(path), str(destination))
            with self.state_lock:
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
            elif a == "carved" and dst and Path(dst).exists():
                Path(dst).unlink()          # carved fragments never go back
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
    p.add_argument("--scan", default=None, metavar="FSFORMAT",
                   help="format filter (comma list or all); the device or "
                        "image path is given as the positional input; "
                        "dummy reports, copy carves to Target/FS-CARVE (V21)")
    p.add_argument("--scan-raw", default=None, metavar="DEVICE",
                   help="scan a raw device/disk image with the 260-signature "
                        "engine; dummy reports, copy carves to Target/RAW-CARVE (V20)")
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
    if args.scan_raw:
        return run_raw_scan(Path(args.scan_raw), args.mode,
                            Path(args.target),
                            Path(args.log) if args.log else None)
    if args.scan:
        if not args.inputs:
            print("SCAN: --scan needs a device or image path")
            return 64
        return run_fs_scan(args.inputs[0], args.scan, args.mode,
                           Path(args.target),
                           Path(args.log) if args.log else None)
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
# NATIVE METADATA (V16.1+ ExifTool era) - embedded, stdlib-only
# JPEG EXIF (APP1/TIFF IFD0) and MP3 ID3v1/ID3v2 parsers + keywords.
# ===========================================================================

EXIF_TAGS = {
    0x010F: "make", 0x0110: "model", 0x0112: "orientation",
    0x0132: "datetime", 0x9003: "dt_original",
    0x829A: "exposure", 0x829D: "fnumber", 0x8827: "iso",
}


def read_exif(path) -> dict:
    """Parse EXIF from a JPEG file. Returns {} when absent/unreadable."""
    try:
        data = Path_read(path)
    except OSError:
        return {}
    if not data.startswith(b"\xff\xd8\xff"):
        return {}
    out: dict = {}
    pos = 2
    n = len(data)
    while pos + 4 < n:
        if data[pos] != 0xFF:
            pos += 1
            continue
        code = data[pos + 1]
        if code in (0xD8, 0x01) or 0xD0 <= code <= 0xD7:
            pos += 2
            continue
        if pos + 4 > n:
            break
        seglen = int.from_bytes(data[pos + 2:pos + 4], "big")
        if seglen < 2 or pos + 2 + seglen > n:
            break
        if code == 0xE1 and data[pos + 4:pos + 10] == b"Exif\x00\x00":
            out.update(_parse_tiff(data, pos + 10))
            break
        pos += 2 + seglen
    return out


def _parse_tiff(buf: bytes, tiff: int) -> dict:
    endian = buf[tiff:tiff + 2]
    if endian == b"II":
        e = "<"
    elif endian == b"MM":
        e = ">"
    else:
        return {}
    if struct.unpack(e + "H", buf[tiff + 2:tiff + 4])[0] != 42:
        return {}
    ifd_off = tiff + struct.unpack(e + "I", buf[tiff + 4:tiff + 8])[0]
    if ifd_off + 2 > len(buf):
        return {}
    out: dict = {}
    try:
        count = struct.unpack(e + "H", buf[ifd_off:ifd_off + 2])[0]
        for i in range(min(count, 256)):
            entry = ifd_off + 2 + i * 12
            if entry + 12 > len(buf):
                break
            tag, typ, cnt = struct.unpack(e + "HHI", buf[entry:entry + 8])
            if tag not in EXIF_TAGS:
                continue
            if typ == 2:                      # ASCII
                if cnt <= 4:
                    raw = buf[entry + 8:entry + 8 + cnt]
                else:
                    off = struct.unpack(e + "I", buf[entry + 8:entry + 12])[0]
                    raw = buf[tiff + off:tiff + off + cnt]
                out[EXIF_TAGS[tag]] = raw.split(b"\x00")[0].decode("utf-8", "replace")
            elif typ == 3:                    # SHORT (inline)
                out[EXIF_TAGS[tag]] = struct.unpack(e + "H", buf[entry + 8:entry + 10])[0]
            elif typ == 4:                    # LONG (inline for count 1)
                out[EXIF_TAGS[tag]] = struct.unpack(e + "I", buf[entry + 8:entry + 12])[0]
            elif typ == 10:                   # RATIONAL
                off = struct.unpack(e + "I", buf[entry + 8:entry + 12])[0]
                num, den = struct.unpack(e + "II", buf[tiff + off:tiff + off + 8])
                out[EXIF_TAGS[tag]] = num / den if den else 0
    except struct.error:
        pass
    return out


def Path_read(path, limit: int = 2 << 20) -> bytes:
    with open(path, "rb") as f:
        return f.read(limit)


__all__ = ["read_exif", "EXIF_TAGS"]


def _decode_text(enc: int, raw: bytes) -> str:
    raw = raw.split(b"\x00", 1)[0] if enc in (0, 3) else raw
    if enc == 0:
        return raw.decode("latin-1", "replace")
    if enc == 1:
        if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
            return raw.decode("utf-16", "replace")
        return raw.decode("utf-16-le", "replace")
    if enc == 2:
        return raw.decode("utf-16-be", "replace")
    return raw.decode("utf-8", "replace")


def _syncsafe(b: bytes) -> int:
    return (b[0] & 0x7F) << 21 | (b[1] & 0x7F) << 14 | \
           (b[2] & 0x7F) << 7 | (b[3] & 0x7F)


def read_id3(path) -> dict:
    """Read ID3v2 (header) and ID3v1 (tail) tags from an MP3 file."""
    out: dict = {}
    try:
        with open(path, "rb") as f:
            head = f.read(1 << 20)
            f.seek(-128, 2)
            tail = f.read(128)
    except OSError:
        return out

    # ---- ID3v2 ----
    if head[:3] == b"ID3":
        ver = head[3]
        size = _syncsafe(head[6:10])
        pos = 10
        end = min(10 + size, len(head))
        name = {b"TIT2": "title", b"TPE1": "artist", b"TALB": "album",
                b"TYER": "year", b"TDRC": "year", b"TRCK": "track",
                b"TCON": "genre"}
        while pos + 10 <= end:
            fid = head[pos:pos + 4]
            if not fid.strip(b"\x00") or fid[0] not in b"ATC":
                break
            if ver == 4:
                fsize = _syncsafe(head[pos + 4:pos + 8])
            else:
                fsize = int.from_bytes(head[pos + 4:pos + 8], "big")
            if fsize <= 0 or pos + 10 + fsize > len(head):
                break
            enc = head[pos + 10]
            value = _decode_text(enc, head[pos + 11:pos + 10 + fsize])
            if fid in name and value:
                out[name[fid]] = value
            pos += 10 + fsize

    # ---- ID3v1 ----
    if len(tail) == 128 and tail[:3] == b"TAG":
        def txt(o: int, ln: int) -> str:
            return tail[o:o + ln].strip(b"\x00 ").decode("latin-1", "replace")
        v1 = {
            "title": txt(3, 30), "artist": txt(33, 30), "album": txt(63, 30),
            "year": txt(93, 4),
        }
        if tail[125:126] == b"\x00" and tail[126]:
            v1["track"] = str(tail[126])
        for k, v in v1.items():
            out.setdefault(k, v)
    return out


__all__ = ["read_id3"]


def _meta_facts(facts):
    """Attach exif / id3 dicts lazily (once per file)."""
    if getattr(facts, "_meta_done", False):
        return facts
    facts.exif = {}
    facts.id3 = {}
    try:
        if facts.mime_main == "image" and facts.mime_sub == "jpeg":
            facts.exif = read_exif(facts.path)
        if facts.mime_sub == "mpeg" or facts.path.suffix.lower() in (".mp3", ".mpga"):
            facts.id3 = read_id3(facts.path)
    except OSError:
        pass
    facts._meta_done = True
    return facts


_orig_keyword_value = TemplateEngine.keyword_value


def _meta_keyword_value(self, facts, kw):
    _meta_facts(facts)
    if kw.startswith("exif-"):
        field = kw[5:]
        if field == "make":
            return str(facts.exif.get("make") or "")
        if field == "model":
            return str(facts.exif.get("model") or "")
        if field == "datetime":
            return str(facts.exif.get("datetime") or facts.exif.get("dt_original") or "")
        if field == "date":
            v = str(facts.exif.get("datetime") or facts.exif.get("dt_original") or "")
            return v[:10]
        if field == "orientation":
            o = facts.exif.get("orientation")
            return str(o) if o not in ("", None) else ""
        return ""
    if kw.startswith("id3-"):
        return str(facts.id3.get(kw[4:]) or "")
    if kw == "title":
        return (facts.id3.get("title") or facts.exif.get("model") or facts.stem or "")
    return _orig_keyword_value(self, facts, kw)


TemplateEngine.keyword_value = _meta_keyword_value


# ===========================================================================
# MAGIC MODULE (V17.5) - --magic: magic-number detection report
# Comprehensive embedded signature table (260 formats). Pure
# standard library; no external commands.
_MAGIC_SPAN = 32774

_MAGIC_TABLE = [
    (64, "3c3c3c3c204f7261636c6520564d2056", "VirtualBox VDI disk", "vdi"),
    (4086, "535741505350414345", "Linux swap area", "img"),
    (60, "424f4f4b4d4f4249", "MOBI e-book", "mobi,prc"),
    (3, "4e54465320202020", "NTFS filesystem", "img"),
    (64, "5f42485266535f4d", "Btrfs filesystem", "img"),
    (32769, "4344303031", "ISO 9660 image", "iso,img"),
    (257, "7573746172", "TAR archive", "tar"),
    (1, "2d6c683?2d", "LHA/LZH archive", "lzh,lha"),
    (44, "5343524d", "S3M module", "s3m"),
    (108, "4d214b21", "Amiga MOD module", "mod"),
    (108, "46545434", "Amiga MOD module", "mod"),
    (108, "46545438", "Amiga MOD module", "mod"),
    (108, "3443484e", "Amiga MOD module", "mod"),
    (108, "3643484e", "Amiga MOD module", "mod"),
    (108, "3843484e", "Amiga MOD module", "mod"),
    (8, "2142444e", "Outlook PST database", "pst"),
    (108, "4d2e4b", "Amiga MOD module", "mod"),
    (1080, "53ef", "Linux ext2/3/4 filesystem", "img"),
    (0, "4c0000000114020000000000c0000000", "Windows shortcut", "lnk"),
    (0, "457874656e646564204d6f64756c65", "FastTracker XM module", "xm"),
    (0, "53514c69746520666f726d61742033", "SQLite database", "db,sqlite,sqlite3"),
    (0, "437265617469766520566f696365", "Creative Voice audio (VOC)", "voc"),
    (0, "414e44524f4944204241434b5550", "Android backup", "ab"),
    (0, "0000000c6a5020200d0a870a", "JPEG 2000 (JP2)", "jp2"),
    (0, "3c53746174615f6474613e", "Stata dataset", "dta"),
    (0, "64383a616e6e6f756e6365", "BitTorrent metainfo", "torrent"),
    (0, "233f52414449414e4345", "Radiance HDR image", "hdr"),
    (0, "7801730d626260", "Apple DMG disk image", "dmg"),
    (0, "636f6e6563746978", "Virtual PC VHD disk image", "vhd"),
    (0, "4349534f", "Compressed ISO image (CSO)", "cso"),
    (0, "445644", "DVD IFO navigation file", "ifo"),
    (0, "02647373", "Digital Speech Standard audio", "dss"),
    (0, "23204469736b2044", "VMware VMDK descriptor", "vmdk"),
    (0, "7472756500", "TrueType font (Mac)", "ttf"),
    (0, "425047fb", "Better Portable Graphics image", "bpg"),
    (0, "424547494e3a5643", "vCard contact file", "vcf"),
    (0, "d7cdc69a", "Windows metafile graphics", "wmf"),
    (0, "c5d0d3c6", "Encapsulated PostScript (binary)", "eps"),
    (0, "cfad12fe", "Outlook Express mail store (DBX)", "dbx"),
    (0, "49491a0000004845", "Canon CRW raw photo", "crw"),
    (0, "e4525c7b8cd8a74d", "OneNote notebook", "one"),
    (0, "0a166f72672e626974636f696e2e7072", "MultiBit Bitcoin wallet", "wallet"),
    (0, "4f50434c444154", "1Password cloud keychain", "opvault"),
    (0, "455646090d0aff00", "EnCase evidence file (E01)", "e01"),
    (0, "0606edf5d81d46e5bd31efe7fe74b71d", "InDesign document", "indd"),
    (0, "6c33336c", "Skype user database", "dbb"),
    (0, "7e424b00", "Paint Shop Pro image", "psp"),
    (0, "300000004c664c65", "Windows event log (EVT)", "evt"),
    (0, "456c6646696c6500", "Windows event log (EVTX)", "evtx"),
    (0, "434f5744", "VMware COWD sparse disk", "vmdk"),
    (0, "2d2d2d2d2d424547494e", "Armored ASCII block (PGP/PEM/SSH)", "asc,pgp,gpg"),
    (0, "52494646????????57454250", "WEBP image", "webp"),
    (0, "52494646????????57415645", "WAV audio", "wav"),
    (0, "52494646????????41564920", "AVI video", "avi"),
    (0, "52494646????????414d5620", "AMV video", "amv"),
    (0, "464f524d????????41494646", "AIFF audio", "aiff,aif"),
    (0, "464f524d????????41494643", "AIFC audio", "aifc"),
    (0, "????????6674797071742020", "QuickTime MOV video", "mov"),
    (0, "????????667479704d344120", "M4A audio", "m4a"),
    (0, "????????667479704d345620", "M4V video", "m4v"),
    (0, "????????6674797068656963", "HEIC/HEIF image", "heic,heif,hif"),
    (0, "????????6674797068656978", "HEIC/HEIF image", "heic,heif,hif"),
    (0, "????????6674797068656966", "HEIC/HEIF image", "heic,heif,hif"),
    (0, "????????667479706d696631", "HEIC/HEIF image", "heic,heif,hif"),
    (0, "????????667479706d736631", "HEIC/HEIF image", "heic,heif,hif"),
    (0, "????????6674797061766966", "AVIF image", "avif"),
    (0, "????????6674797061766973", "AVIF image", "avif"),
    (0, "????????667479706a703220", "JPEG 2000 (JP2)", "jp2"),
    (0, "????????6674797033677034", "3GP video", "3gp"),
    (0, "????????6674797033677035", "3GP video", "3gp"),
    (0, "????????6674797033677036", "3GP video", "3gp"),
    (0, "????????6674797033673261", "3G2 video", "3g2"),
    (0, "????????6674797069736f6d", "MP4 video", "mp4"),
    (0, "????????6674797069736f32", "MP4 video", "mp4"),
    (0, "????????667479706d703431", "MP4 video", "mp4"),
    (0, "????????667479706d703432", "MP4 video", "mp4"),
    (0, "????????6674797061766331", "MP4 video", "mp4"),
    (0, "????????6674797064617368", "DASH video", "mpd,m4s,mp4"),
    (0, "????????6674797066347620", "Flash F4V video", "f4v"),
    (0, "52494646????????41434f4e", "Windows animated cursor", "ani"),
    (0, "464f524d????????494c424d", "Amiga ILBM image", "iff,lbm"),
    (0, "464f524d????????38535658", "Amiga 8SVX audio", "iff,8svx"),
    (0, "464f524d????????4d415544", "Amiga MAUD audio", "maud"),
    (0, "52494646????????524d4944", "RIFF MIDI (RMID)", "rmi"),
    (0, "52494646????????7366626b", "SoundFont SF2", "sf2"),
    (0, "????????6674797068766331", "HEVC video", "hevc,h265"),
    (0, "????????6674797068657631", "HEVC video", "hevc,h265"),
    (0, "????????6674797061763031", "AV1 video", "av1"),
    (0, "????????6674797044495658", "DivX video", "divx"),
    (0, "????????667479704d344220", "M4B audiobook", "m4b"),
    (0, "67696d7020786366", "GIMP XCF image", "xcf"),
    (0, "3026b2758e66cf11", "ASF media (WMA/WMV)", "wma,wmv,asf"),
    (0, "d0cf11e0a1b11ae1", "MS Office/OLE compound", "doc,xls,ppt,msi,cfg"),
    (0, "41542654464f524d", "DjVu document", "djvu,djv"),
    (0, "49544f4c49544c53", "MS Reader LIT e-book", "lit"),
    (0, "7668647866696c65", "Hyper-V VHDX disk", "vhdx"),
    (0, "2321414d522d5742", "AMR-WB speech audio", "amr"),
    (0, "50532d5820455845", "PlayStation executable", "exe"),
    (0, "414e44524f494421", "Android boot image", "img"),
    (0, "5041474544554d50", "Windows kernel dump", "dmp"),
    (0, "5041474544553634", "Windows kernel dump (64-bit)", "dmp"),
    (0, "52494646????????434452", "CorelDRAW document", "cdr"),
    (0, "213c617263683e", "AR archive (deb/static lib)", "a,deb"),
    (0, "53747566664974", "StuffIt archive", "sit"),
    (0, "49492a00????????4352", "Canon CR2 raw image", "cr2"),
    (0, "233f52474245", "Radiance HDR image", "hdr"),
    (0, "377abcaf271c", "7-Zip archive", "7z"),
    (0, "526172211a07", "RAR archive", "rar"),
    (0, "303730373031", "CPIO archive (newc)", "cpio"),
    (0, "303730373037", "CPIO archive (odc)", "cpio"),
    (0, "2a2a4143452a", "ACE archive", "ace"),
    (0, "7b5c72746631", "RTF document", "rtf"),
    (0, "4c554b53babe", "LUKS encrypted volume", "luks,img"),
    (0, "53494d504c45", "FITS astronomy image", "fits"),
    (0, "4152524f5731", "Apache Arrow IPC data", "arrow"),
    (0, "4d41544c4142", "MATLAB MAT-file", "mat"),
    (0, "0d0a870a0a", "JPEG XL container", "jxl"),
    (0, "3c3f786d6c", "XML document", "xml,svg,fb2,rss,xsl,plist"),
    (0, "2321414d52", "AMR speech audio", "amr"),
    (0, "fd377a585a", "XZ stream", "xz,txz"),
    (0, "4d5357494d", "Windows Imaging archive", "wim"),
    (0, "4e45534d1a", "NES sound file", "nsf"),
    (0, "5245444953", "Redis RDB snapshot", "rdb"),
    (0, "????????66747970", "MP4/QuickTime container", "mp4,m4a,mov,3gp,heic"),
    (0, "89504e47", "PNG image", "png"),
    (0, "ff4fff51", "JPEG 2000 codestream", "j2k,jpc"),
    (0, "47494638", "GIF image", "gif"),
    (0, "49492a00", "TIFF image (little-endian)", "tif,tiff"),
    (0, "4d4d002a", "TIFF image (big-endian)", "tif,tiff"),
    (0, "38425053", "Photoshop PSD image", "psd,pdd"),
    (0, "44445320", "DirectDraw Surface texture", "dds"),
    (0, "762f3101", "OpenEXR image", "exr"),
    (0, "00020000", "Windows cursor", "cur"),
    (0, "00010000", "ICO icon / TrueType font", "ico,ttf,otf"),
    (0, "69636e73", "Apple ICNS icon", "icns"),
    (0, "3c737667", "SVG image", "svg"),
    (0, "52494646", "RIFF container", "wav,avi,webp"),
    (0, "46524d38", "DSDIFF audio (DFF)", "dff"),
    (0, "63616666", "Apple CAF audio", "caf"),
    (0, "44534420", "DSD streamfile audio (DSF)", "dsf"),
    (0, "664c6143", "FLAC audio", "flac"),
    (0, "4f676753", "OGG media", "ogg,oga,opus,ogv,ogx"),
    (0, "4d546864", "MIDI music", "mid,midi,rmi,kar"),
    (0, "2e736e64", "NeXT/Sun AU audio", "au,snd"),
    (0, "4d414320", "Monkey Audio (APE)", "ape"),
    (0, "7770766b", "WavPack audio", "wv"),
    (0, "4d50434b", "Musepack audio (SV8)", "mpc"),
    (0, "54544131", "True Audio (TTA)", "tta"),
    (0, "616a6b67", "Shorten audio", "shn"),
    (0, "494d504d", "Impulse Tracker module", "it"),
    (0, "1a45dfa3", "Matroska/WebM video", "mkv,webm,mka,mks"),
    (0, "000001ba", "MPEG program stream", "mpg,mpeg,vob,ps"),
    (0, "000001b3", "MPEG elementary video", "m2v,mpv,mpg"),
    (0, "2e524d46", "RealMedia video", "rm,rmvb"),
    (0, "060e2b34", "MXF video", "mxf"),
    (0, "504b0304", "ZIP/Office document", "zip,docx,xlsx,pptx,odt,jar,apk,epub"),
    (0, "504b0506", "ZIP archive (empty)", "zip"),
    (0, "504b0708", "ZIP archive (spanned)", "zip"),
    (0, "28b52ffd", "Zstandard stream", "zst"),
    (0, "04224d18", "LZ4 frame", "lz4"),
    (0, "5d000080", "LZMA-alone stream", "lzma"),
    (0, "894c5a4f", "LZO compressed archive", "lzo"),
    (0, "4d534346", "MS Cabinet archive", "cab"),
    (0, "edabeedb", "RPM package", "rpm"),
    (0, "50415231", "Apache Parquet data", "parquet"),
    (0, "25504446", "PDF document", "pdf"),
    (0, "25215053", "PostScript/EPS document", "ps,eps,ai"),
    (0, "49545346", "MS Compiled HTML (CHM)", "chm"),
    (0, "4f54544f", "OpenType (CFF) font", "otf"),
    (0, "74746366", "TrueType collection", "ttc"),
    (0, "774f4646", "WOFF font", "woff"),
    (0, "774f4632", "WOFF2 font", "woff2"),
    (0, "7f454c46", "ELF binary", "so,bin,elf,o,ko"),
    (0, "feedface", "Mach-O binary (32-bit BE)", "bin"),
    (0, "cefaedfe", "Mach-O binary (32-bit LE)", "bin"),
    (0, "feedfacf", "Mach-O binary (64-bit BE)", "bin"),
    (0, "cffaedfe", "Mach-O binary (64-bit LE)", "bin"),
    (0, "cafebabe", "Java class / Mach-O fat binary", "class,bin"),
    (0, "0061736d", "WebAssembly module", "wasm"),
    (0, "6465780a", "Android DEX bytecode", "dex,odex"),
    (0, "72656766", "Windows registry hive", "dat,hive,reg"),
    (0, "a1b2c3d4", "pcap packet capture", "pcap,cap"),
    (0, "d4c3b2a1", "pcap packet capture (swapped)", "pcap,cap"),
    (0, "0a0d0d0a", "pcapng packet capture", "pcapng"),
    (0, "4f626a01", "Apache Avro object container", "avro"),
    (0, "43723234", "Chrome extension (CRX)", "crx"),
    (0, "514649fb", "QEMU copy-on-write disk", "qcow,qcow2"),
    (0, "4b444d56", "VMware VMDK disk", "vmdk"),
    (0, "4d4d002b", "TIFF image (BigTIFF)", "tif,tiff"),
    (0, "4949524f", "Olympus ORF raw image", "orf"),
    (0, "49495500", "Panasonic RW2 raw image", "rw2"),
    (0, "4949bc01", "JPEG XR image", "jxr,wdp,hdp"),
    (0, "464c4946", "FLIF image", "flif"),
    (0, "ab4b5458", "KTX/KTX2 texture", "ktx,ktx2"),
    (0, "716f6966", "QOI image", "qoi"),
    (0, "4f465220", "OptimFROG audio", "ofr"),
    (0, "7fff8001", "DTS audio", "dts"),
    (0, "50534944", "Commodore SID tune", "sid"),
    (0, "56676d20", "Video Game Music tune", "vgm"),
    (0, "6e75742f", "NUT video", "nut"),
    (0, "78617221", "XAR archive", "xar"),
    (0, "5041434b", "Git packfile / Quake PAK", "pack,pak"),
    (0, "4d50511a", "Blizzard MPQ archive", "mpq"),
    (0, "49574144", "Doom IWAD game archive", "wad"),
    (0, "50574144", "Doom PWAD game archive", "wad"),
    (0, "444d5321", "Amiga DMS archive", "dms"),
    (0, "4e45531a", "NES ROM image", "nes"),
    (0, "80371240", "Nintendo 64 ROM", "n64,z64"),
    (0, "37804012", "Nintendo 64 ROM (swapped)", "n64,v64"),
    (0, "53454741", "SEGA Mega Drive ROM", "md,gen"),
    (0, "3f5f0300", "Windows Help file", "hlp"),
    (0, "504e5264", "eReader PDB e-book", "pdb"),
    (0, "3c3f7068", "PHP script", "php"),
    (0, "4d444d50", "Windows minidump", "dmp"),
    (0, "aced0005", "Java serialized object", "ser"),
    (0, "feedfeed", "Java keystore", "jks"),
    (0, "58465342", "XFS filesystem", "img"),
    (0, "89484446", "HDF5 dataset", "h5,hdf5"),
    (0, "43444601", "NetCDF classic dataset", "nc"),
    (0, "43444602", "NetCDF 64-bit dataset", "nc"),
    (0, "52445832", "R binary data", "rdata,rds"),
    (0, "42414d01", "BAM sequence data", "bam"),
    (0, "4352414d", "CRAM sequence data", "cram"),
    (0, "44495243", "Git index", "index"),
    (0, "4d4d443?", "Amiga MED module", "med"),
    (0, "ffd8ff", "JPEG image", "jpg,jpeg,jfif"),
    (0, "0a0000", "PCX image", "pcx"),
    (0, "0a0200", "PCX image", "pcx"),
    (0, "0a0300", "PCX image", "pcx"),
    (0, "0a0500", "PCX image", "pcx"),
    (0, "494433", "MP3 audio (ID3v2 tag)", "mp3"),
    (0, "4d502b", "Musepack audio", "mpc"),
    (0, "464c56", "Flash video (FLV)", "flv"),
    (0, "42494b", "Bink video", "bik,bk2"),
    (0, "425a68", "BZIP2 stream", "bz2,tbz2"),
    (0, "1f9d8d", "compress (.Z) archive", "z"),
    (0, "5a4f4f", "ZOO archive", "zoo"),
    (0, "435753", "Shockwave Flash (compressed)", "swf"),
    (0, "465753", "Shockwave Flash", "swf"),
    (0, "5a5753", "Shockwave Flash (LZMA)", "swf"),
    (0, "50370a", "PAM image", "pam"),
    (0, "4d544d", "Multitracker module", "mtm"),
    (0, "800106", "Type 1 font (PFB)", "pfb"),
    (0, "4f5243", "Apache ORC data", "orc"),
    (0, "ff0a", "JPEG XL codestream", "jxl"),
    (0, "424d", "BMP image", "bmp,dib"),
    (0, "5034", "PBM image", "pbm"),
    (0, "5035", "PGM image", "pgm"),
    (0, "5036", "PPM image", "ppm"),
    (0, "fffb", "MP3 audio (MPEG-1)", "mp3"),
    (0, "fff3", "MP3 audio (MPEG-2)", "mp3"),
    (0, "fff2", "MP3 audio (MPEG-2.5)", "mp3"),
    (0, "ffe3", "MP3 audio (MPEG-2.5 LSF)", "mp3"),
    (0, "fff1", "AAC audio (ADTS)", "aac,adts"),
    (0, "fff9", "AAC audio (ADTS)", "aac,adts"),
    (0, "1f8b", "GZIP stream", "gz,tgz"),
    (0, "60ea", "ARJ archive", "arj"),
    (0, "7ffe", "Bourne shell archive", "shar"),
    (0, "4d5a", "DOS/PE executable", "exe,dll,sys,ocx,scr"),
    (0, "2321", "Script (#!)", "sh,py,pl,rb,el,js,ts"),
]


def magic_hex(path) -> str:
    """First 32774 bytes of the file as one lowercase hex string."""
    try:
        with open(path, "rb") as fh:
            return fh.read(_MAGIC_SPAN).hex()
    except OSError:
        return ""


def _magic_match(h: str, off: int, sig: str) -> bool:
    """True when sig (hex, '?' = any nibble) matches h at byte offset off."""
    pos = off * 2
    if len(h) < pos + len(sig):
        return False
    for i, c in enumerate(sig):
        if c != "?" and h[pos + i] != c:
            return False
    return True


def magic_detect(hexstr: str):
    """Match a hex signature against the table -> (name, exts) or ('?', '')."""
    h = hexstr.lower()
    # MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376
    if (len(h) >= 754 and h[0:2] == "47"
            and h[376:378] == "47" and h[752:754] == "47"):
        return "MPEG-TS", "ts,m2ts,mts"
    for off, sig, name, exts in _MAGIC_TABLE:
        if _magic_match(h, off, sig):
            return name, exts
    return "?", ""


def magic_report(path) -> str:
    """One four-line report block for a single file."""
    h = magic_hex(path) or "(empty)"
    name, exts = magic_detect(h)
    ext = path.suffix.lstrip(".").lower() if path.suffix else "(none)"
    if name == "?":
        verdict = "UNKNOWN"
    elif ext == "(none)":
        verdict = "NO-EXT"
    elif ext in exts.split(","):
        verdict = "MATCH"
    else:
        verdict = "MISMATCH"
    return (f"{path}\nmagic: {h[:32]}\ndetected: {name}\n"
            f"extension: {ext}\nverdict: {verdict}")



# ===========================================================================
# RAW DEVICE SCAN (V20) - --scan-raw: signature walk + optional carving
# ===========================================================================
# Scans a raw block device (/dev/sdX, /dev/sdX1) or a disk image file with
# the same 260-entry magic table used by --magic. Every byte offset is a
# candidate; hits can be carved out in copy mode (dry-run reports only).
# The device is only ever opened read-only; --scan-raw refuses
# remove/trash/shred.

_RAW_BLOCK = 1 << 20
_RAW_CARRY = 32800            # max entry offset (32769) + max signature
_RAW_CARVE_MAX = 5 << 20      # fragment cap for formats without an end rule


def _raw_patterns():
    """(off, name, exts, literal_bytes | None, regex | None) per entry."""
    pats = []
    for off, sig, name, exts in _MAGIC_TABLE:
        if len(sig) < 4:
            continue          # 1-byte signatures are noise on raw media
        if "?" not in sig:
            pats.append((off, name, exts, bytes.fromhex(sig), None))
            continue
        out = b""
        ok = True
        for i in range(0, len(sig), 2):
            hi, lo = sig[i], sig[i + 1]
            if hi == "?" and lo == "?":
                out += b"."
            elif lo == "?":
                cls = bytes(range(int(hi, 16) * 16, int(hi, 16) * 16 + 16))
                out += b"[" + re.escape(cls) + b"]"
            elif hi == "?":
                cls = bytes(range(int(lo, 16), 256, 16))
                out += b"[" + re.escape(cls) + b"]"
            else:
                out += re.escape(bytes([int(sig[i:i + 2], 16)]))
        pats.append((off, name, exts, None, re.compile(out, re.DOTALL)))
    return pats


_RAW_END_RULES = {
    "PNG image": "png", "JPEG image": "jpeg", "GIF image": "gif",
    "ZIP archive": "zip", "PDF document": "pdf",
}


def _raw_carve_size(head: bytes, name: str, cap: int):
    """Estimate the fragment length -> (size, exact). exact=True means the
    format itself said where it ends; False means the cap was applied."""
    try:
        if name.startswith("PNG image"):
            pos = 8
            while pos + 12 <= len(head):
                import struct as _st
                clen = _st.unpack(">I", head[pos:pos + 4])[0]
                ctype = head[pos + 4:pos + 8]
                pos += 12 + clen             # len + type + data + CRC
                if ctype == b"IEND":
                    return min(pos, cap), True
                if clen > len(head):
                    return min(pos, cap), False
            return min(len(head), cap), False
        if name.startswith("JPEG image"):
            end = head.rfind(b"\xff\xd9")
            return ((end + 2), True) if end != -1 else (min(len(head), cap), False)
        if name.startswith("GIF image"):
            end = head.rfind(b"\x3b", 13)
            return ((end + 1), True) if end != -1 else (min(len(head), cap), False)
        if name.startswith("ZIP/") or name.startswith("ZIP archive"):
            end = head.rfind(b"PK\x05\x06")
            if end != -1 and end + 22 <= len(head):
                import struct as _st
                comment = _st.unpack(">H", head[end + 20:end + 22])[0]
                return end + 22 + comment, True
            return min(len(head), cap), False
        if name.startswith("PDF document"):
            end = head.rfind(b"%%EOF")
            return ((end + 5), True) if end != -1 else (min(len(head), cap), False)
    except Exception:
        pass
    return min(len(head), cap), False


def scan_raw(path, carve_max: int = _RAW_CARVE_MAX):
    """Yield (offset, name, exts, size) for every magic hit in the stream."""
    pats = _raw_patterns()
    try:
        f = open(path, "rb", buffering=0)
        probe = open(path, "rb", buffering=0)
    except OSError as exc:
        print(f"RAW-SCAN: cannot open {path}: {exc}")
        return
    base = 0
    carry = b""
    total = 0
    next_allowed = 0
    try:
        while True:
            block = f.read(_RAW_BLOCK)
            if not block:
                break
            total += len(block)
            buf = carry + block if carry else block
            buf_base = base - len(carry)
            hits = []
            for off, name, exts, lit, rx in pats:
                if lit is not None:
                    start = 0
                    while True:
                        pos = buf.find(lit, start)
                        if pos == -1:
                            break
                        hit = buf_base + pos - off
                        if hit >= 0:
                            hits.append((hit, name, exts))
                        start = pos + 1
                else:
                    for m in rx.finditer(buf):
                        hit = buf_base + m.start() - off
                        if hit >= 0:
                            hits.append((hit, name, exts))
            hits.sort()
            for hit, name, exts in hits:
                if hit < next_allowed:
                    continue
                probe.seek(hit)
                head = probe.read(min(carve_max, _RAW_BLOCK))
                size, exact = _raw_carve_size(head, name, carve_max)
                # an exact fragment owns its byte range; a capped guess only
                # suppresses hits at the very same offset
                next_allowed = (hit + size) if exact else (hit + 1)
                yield hit, name, exts, size, exact
            base += len(block)
            carry = buf[-_RAW_CARRY:]
    finally:
        f.close()
        probe.close()


def run_raw_scan(raw_path, mode: str, target, log=None) -> int:
    """Report (dummy) or carve (copy) the hits found in a raw device/image."""
    if mode in ("move", "remove", "trash", "shred"):
        print(f"RAW-SCAN: --scan-raw supports dummy and copy only "
              f"(mode '{mode}' refused)")
        return 64
    ext_of = lambda exts: (exts.split(",")[0] if exts else "bin")
    count = 0
    outdir = target / "RAW-CARVE"
    if mode == "copy":
        outdir.mkdir(parents=True, exist_ok=True)
    print(f"RAW-SCAN: {raw_path}")
    for hit, name, exts, size, exact in scan_raw(raw_path):
        count += 1
        print(f"  hit: 0x{hit:012x} {hit} {name} -> {ext_of(exts)} "
              f"(carve {size} bytes{'' if exact else ', capped'})")
        if mode == "copy":
            dest = outdir / (f"{hit:012x}.{ext_of(exts)}")
            try:
                with open(raw_path, "rb") as src, open(dest, "wb") as dst:
                    src.seek(hit)
                    remaining = size
                    while remaining > 0:
                        chunk = src.read(min(1 << 20, remaining))
                        if not chunk:
                            break
                        dst.write(chunk)
                        remaining -= len(chunk)
                print(f"  carved: {dest}")
                if log:
                    with open(log, "a", encoding="utf-8") as lf:
                        lf.write(json.dumps({"action": "carved",
                                             "src": f"{raw_path}@{hit}",
                                             "dst": str(dest)}) + "\n")
            except OSError as exc:
                print(f"  carve failed at 0x{hit:012x}: {exc}")
    print(f"RAW-SCAN: {count} signatures found")
    return 0


# ===========================================================================
# FS SCAN MODULE (V21) - --scan=FSFormat: partition map + per-partition scan
# ===========================================================================
# Scans a raw device or disk image in two phases:
#   1. partition discovery: MBR + GPT entries, plus a 512-byte-aligned
#      filesystem-signature probe that finds deleted/lost partitions
#   2. per selected partition: the V20 signature engine (260 formats)
#      runs inside the partition range; fragments that cross the partition
#      end or overlap another partition are marked "broken" (overwritten)
# Modes: dummy (report only, default) and copy (carve to Target/FS-CARVE).
# The source is only ever opened read-only.

_FS_PROBE_LEN = 1200        # covers ext superblock (1024+56) and swap sig
_FS_SECTOR = 512
_FS_FORMATS = ("all", "ntfs", "exfat", "fat12", "fat16", "fat32", "ext",
               "btrfs", "xfs", "reiserfs", "hfs", "swap", "luks")


def _fs_size(f):
    """True byte size of an open file or block device (best effort)."""
    try:
        f.seek(0, 2)
        n = f.tell()
        if n > 0:
            return n
    except OSError:
        pass
    try:                                    # Linux block devices
        import fcntl
        import struct as _st
        buf = fcntl.ioctl(f.fileno(), 0x80081272, _st.pack("Q", 0))  # BLKGETSIZE64
        return _st.unpack("Q", buf)[0]
    except Exception:
        return 0


def _fs_probe(b):
    """Return the filesystem token for a partition-start window, or None."""
    if len(b) < 64:
        return None
    if b[0:6] == b"LUKS\xba\xbe":
        return "luks"
    if b[3:11] == b"NTFS    ":
        return "ntfs"
    if b[3:8] == b"EXFAT ":
        return "exfat"
    if b[54:59] == b"FAT16":
        return "fat16"
    if b[54:59] == b"FAT12":
        return "fat12"
    if b[82:87] == b"FAT32":
        return "fat32"
    if b[64:72] == b"_BHRfS_M":
        return "btrfs"
    if b[0:4] == b"XFSB":
        return "xfs"
    if b[52:60] in (b"ReIsErFs", b"ReIsEr2Fs", b"ReIsEr3Fs", b"ReIsEr4Fs"):
        return "reiserfs"
    if len(b) >= 1026 and b[1024:1026] in (b"H+", b"HX"):
        return "hfs"
    if len(b) >= 1082 and b[1080:1082] == b"\x53\xef":     # ext superblock magic
        return "ext"
    if len(b) >= 1062 and b[1052:1062] == b"SWAPSPACE2":
        return "swap"
    return None


def _fs_norm(fmt):
    """Normalize a user-supplied format token (case/aliases)."""
    f = fmt.strip().lower()
    if f in ("ext2", "ext3", "ext4"):
        f = "ext"
    if f in ("hfs+", "hfsx", "hfsplus"):
        f = "hfs"
    return f


def _fs_listed(f, fsize):
    """MBR + GPT entries -> [(start, size, type_byte_or_None)]."""
    out = []
    f.seek(0)
    mbr = f.read(512)
    if len(mbr) < 512 or mbr[510:512] != b"\x55\xaa":
        return out
    types = [mbr[446 + 16 * i + 4] for i in range(4)]
    if 0xEE in types:                       # GPT protective MBR
        f.seek(512)
        hdr = f.read(512)
        if hdr[0:8] == b"EFI PART":
            import struct as _st
            elba = _st.unpack("<Q", hdr[72:80])[0]
            nent = _st.unpack("<I", hdr[80:84])[0]
            esz = _st.unpack("<I", hdr[84:88])[0]
            if esz >= 128 and nent > 0 and nent * esz <= 4 << 20:
                f.seek(elba * _FS_SECTOR)
                blob = f.read(nent * esz)
                for i in range(nent):
                    e = blob[i * esz:(i + 1) * esz]
                    if len(e) < 128 or not any(e[0:16]):
                        continue
                    first = _st.unpack("<Q", e[32:40])[0]
                    last = _st.unpack("<Q", e[40:48])[0]
                    if last < first:
                        continue
                    start = first * _FS_SECTOR
                    size = (last - first + 1) * _FS_SECTOR
                    if 0 < size <= fsize:
                        out.append((start, size, None))
            return out
    for i in range(4):                      # classic MBR
        tb = types[i]
        if tb in (0x00, 0x05, 0x0F, 0xEE, 0x85):     # empty / extended / GPT
            continue
        import struct as _st
        lba = _st.unpack("<I", mbr[446 + 16 * i + 8:446 + 16 * i + 12])[0]
        nsec = _st.unpack("<I", mbr[446 + 16 * i + 12:446 + 16 * i + 16])[0]
        start = lba * _FS_SECTOR
        size = nsec * _FS_SECTOR
        if nsec > 0 and start + size <= fsize:
            out.append((start, size, tb))
    return out


def fs_partitions(path):
    """[(start, size, fstype, status)] - status 'listed' or 'lost'.
    fstype may be None when a table entry exists but no filesystem was
    detected at its start (raw / unknown partition)."""
    try:
        f = open(path, "rb", buffering=0)
    except OSError as exc:
        print(f"SCAN: cannot open {path}: {exc}")
        return None
    with f:
        fsize = _fs_size(f)
        parts = []
        for start, size, tb in _fs_listed(f, fsize):
            f.seek(start)
            fst = _fs_probe(f.read(_FS_PROBE_LEN))
            parts.append([start, size, fst, "listed"])
        if fsize <= 0:
            if not parts:
                print(f"SCAN: cannot determine size of {path}")
                return None
            fsize = max(p[0] + p[1] for p in parts)
        inside = [(p[0], p[0] + p[1]) for p in parts]
        off = 0
        while off < fsize:
            if not any(a <= off < b for a, b in inside):
                f.seek(off)
                w = f.read(_FS_PROBE_LEN)
                fst = _fs_probe(w)
                if fst:
                    nxt = fsize
                    for a, b in inside:
                        if a > off:
                            nxt = min(nxt, a)
                    parts.append([off, nxt - off, fst, "lost"])
            off += _FS_SECTOR
        parts.sort(key=lambda p: p[0])
        # keep 'listed' first in numbering: rebuild index by status then start
        listed = [p for p in parts if p[3] == "listed"]
        lost = [p for p in parts if p[3] == "lost"]
        return fsize, listed + lost


def _fs_overlap(parts, pidx, hit, size):
    """True when the fragment [hit, hit+size) leaves its partition or
    crosses into another one (overwritten data -> 'broken')."""
    start, psize = parts[pidx][0], parts[pidx][1]
    end = start + psize
    if hit + size > end:
        return True
    for i, p in enumerate(parts):
        if i == pidx:
            continue
        if hit < p[0] + p[1] and hit + size > p[0]:
            return True
    return False


def scan_raw_range(path, lo, hi, carve_max=_RAW_CARVE_MAX):
    """Like scan_raw() but limited to absolute offsets [lo, hi)."""
    pats = _raw_patterns()
    try:
        f = open(path, "rb", buffering=0)
        probe = open(path, "rb", buffering=0)
    except OSError as exc:
        print(f"SCAN: cannot open {path}: {exc}")
        return
    base = 0
    carry = b""
    next_allowed = lo
    try:
        while base < hi:
            block = f.read(_RAW_BLOCK)
            if not block:
                break
            buf = carry + block if carry else block
            buf_base = base - len(carry)
            hits = []
            for off, name, exts, lit, rx in pats:
                if lit is not None:
                    start = 0
                    while True:
                        pos = buf.find(lit, start)
                        if pos == -1:
                            break
                        hit = buf_base + pos - off
                        if lo <= hit < hi:
                            hits.append((hit, name, exts))
                        start = pos + 1
                else:
                    for m in rx.finditer(buf):
                        hit = buf_base + m.start() - off
                        if lo <= hit < hi:
                            hits.append((hit, name, exts))
            hits.sort()
            for hit, name, exts in hits:
                if hit < next_allowed:
                    continue
                probe.seek(hit)
                head = probe.read(min(carve_max, _RAW_BLOCK))
                size, exact = _raw_carve_size(head, name, carve_max)
                next_allowed = (hit + size) if exact else (hit + 1)
                yield hit, name, exts, size, exact
            base += len(block)
            carry = buf[-_RAW_CARRY:]
    finally:
        f.close()
        probe.close()


def _fs_write(srcf, dest, hit, size):
    """Carve one fragment; return (ok, oos). oos = out of space."""
    import errno
    srcf.seek(hit)
    with open(dest, "wb") as dst:
        remaining = size
        while remaining > 0:
            buf = srcf.read(min(remaining, 1 << 20))
            if not buf:
                break
            try:
                dst.write(buf)
            except OSError as exc:
                return False, exc.errno == errno.ENOSPC
            remaining -= len(buf)
    return True, False


def run_fs_scan(fs_path, formats, mode, target, log=None) -> int:
    """Report (dummy) or carve (copy) per-partition signature hits."""
    if mode in ("move", "remove", "trash", "shred"):
        print(f"SCAN: --scan supports dummy and copy only "
              f"(mode '{mode}' refused)")
        return 64
    fmts = []
    for tok in (formats or "all").split(","):
        tok = _fs_norm(tok)
        if tok == "":
            continue
        if tok not in _FS_FORMATS:
            print(f"SCAN: unknown filesystem format '{tok}' "
                  f"(known: {','.join(_FS_FORMATS)})")
            return 64
        fmts.append(tok)
    if not fmts or "all" in fmts:
        fmts = [f for f in _FS_FORMATS if f != "all"]

    res = fs_partitions(fs_path)
    if res is None:
        return 66
    fsize, parts = res
    print(f"SCAN: {fs_path}")
    for i, (start, size, fst, status) in enumerate(parts, 1):
        sz = f"~{size}" if status == "lost" else f"{size}"
        print(f"  part {i}: 0x{start:012x} {start} {sz} "
              f"{fst or 'unknown'} {status}")
    nlist = sum(1 for p in parts if p[3] == "listed")
    print(f"SCAN: {len(parts)} partitions found "
          f"({nlist} listed, {len(parts) - nlist} lost)")

    todo = []
    for i, (start, size, fst, status) in enumerate(parts):
        if not fst or fst not in fmts or size <= 0:
            continue
        todo.append(i)
    lf = open(log, "a", encoding="utf-8") if log else None
    srcf = open(fs_path, "rb", buffering=0)
    total = 0
    scanned = 0
    rc = 0
    try:
        for i in todo:
            start, size, fst, status = parts[i]
            print(f"SCAN-PART {i + 1} {fst} 0x{start:012x} {size}")
            nhits = 0
            for hit, name, exts, hsize, exact in \
                    scan_raw_range(fs_path, start, start + size):
                if "filesystem" in name or name == "Linux swap area":
                    continue      # partition signature, not a file fragment
                broken = _fs_overlap(parts, i, hit, hsize)
                total += 1
                nhits += 1
                print(f"  hit: 0x{hit:012x} {hit} {name} -> "
                      f"{exts.split(',')[0]} (carve {hsize} bytes"
                      f"{'' if exact else ', capped'}"
                      f"{', broken' if broken else ''})")
                if mode != "copy":
                    continue
                ext = exts.split(",")[0]
                outdir = (target / "FS-CARVE" /
                          f"p{i + 1}-{start:012x}")
                while True:
                    os.makedirs(outdir, exist_ok=True)
                    dest = outdir / f"{hit:012x}.{ext}"
                    ok, oos = _fs_write(srcf, dest, hit, hsize)
                    if ok:
                        break
                    if oos and sys.stdin is not None and \
                            sys.stdin.isatty():
                        print(f"SCAN: out of space at {outdir}")
                        newt = input("SCAN: new target directory "
                                     "(empty = abort): ").strip()
                        if not newt:
                            print("SCAN: copy aborted by user")
                            return 65
                        outdir = (Path(newt) / "FS-CARVE" /
                                  f"p{i + 1}-{start:012x}")
                        continue
                    print(f"SCAN: cannot write {dest}")
                    return 65
                print(f"  carved: {dest}")
                if lf:
                    entry = {"action": "carved",
                             "src": f"{fs_path}@{hit}",
                             "dst": str(dest), "part": i + 1}
                    if broken:
                        entry["broken"] = True
                    lf.write(json.dumps(entry) + "\n")
            scanned += 1
            print(f"SCAN-PART {i + 1}: {nhits} signatures found")
    finally:
        srcf.close()
        if lf:
            lf.close()
    print(f"SCAN: done, {total} signatures in {scanned} partitions")
    return rc


# ===========================================================================
# EDITION GATE - auto-generated for Sort-V22
# Scope derived mechanically from Sort-V22.sh (era vocabulary).
# Run with --self-test to verify this engine, -h for the era usage.
# ===========================================================================

EDITION = {'version': 'V21', 'modes': ['copy', 'dummy', 'move', 'remove', 'shred', 'trash'], 'flags': ['--dirs', '--scan', '--scan-raw', '--extension', '--hidden', '--jobs', '--lang', '--links', '--log', '--magic', '--no-colors', '--pause', '--quiet', '--recursive', '--rename', '--replace', '--subdirs', '--target', '--type', '--undo'], 'keywords': ['accessed', 'created', 'day', 'exif-date', 'exif-datetime', 'exif-make', 'exif-model', 'exif-orientation', 'extension', 'format', 'format+size', 'id3-album', 'id3-artist', 'id3-genre', 'id3-title', 'id3-track', 'id3-year', 'md5sum', 'mime', 'mime-main', 'mime-sub', 'modified', 'month', 'name', 'random', 'sha1sum', 'sha224sum', 'sha256sum', 'sha384sum', 'sha512sum', 'size', 'size+format', 'title', 'year', 'year+month', 'year+month+day'], 'modifiers': [], 'fallbacks': True, 'stripped': {'--decompress': 'archive decompress (--decompress) - stripped', '--delete': 'delete mode - use --mode=remove', '--exif': 'EXIF rename/strip levels (--exif) - stripped', '--needed': 'dependency listing - stripped', '--noconfirm': 'interactive confirm - stripped', '--non-interactive': 'interactive confirm - stripped', '--stats': 'stats mode (--stats) - stripped', '--strip': 'metadata stripping (--strip) - stripped', '--title': 'metadata title rename (--title) - stripped', '--verbose': 'verbose flag - use default output', '--version': '--version'}}

CANONICAL_KEYWORDS = ["year", "month", "day", "year+month", "year+month+day", "created", "created-date", "created-time", "modified", "modified-date", "modified-time", "accessed", "accessed-date", "accessed-time", "mime", "mime-main", "mime-sub", "type", "extension", "ext", "ext-lower", "ext-upper", "filename", "name", "basename", "stem", "original", "size", "format", "size+format", "format+size", "pixel-size", "resolution", "pixel-format", "md5sum", "sha1sum", "sha224sum", "sha256sum", "sha384sum", "sha512sum", "random"]
CANONICAL_KEYWORDS = CANONICAL_KEYWORDS + ['exif-date', 'exif-datetime', 'exif-make', 'exif-model', 'exif-orientation', 'id3-album', 'id3-artist', 'id3-genre', 'id3-title', 'id3-track', 'id3-year', 'title']

_ERA_USAGE = """Sort-V22.py - standalone Python edition of Sort-V22.sh
(Standard library only; no external commands, no other files required.)

USAGE
    Sort-V22.py [OPTIONS] FILES...

MODES (--mode=...)
    copy, dummy, move, remove, shred, trash

OPTIONS
    --dirs, --extension, --hidden, --jobs, --lang, --links, --log, --magic, --mode, --no-colors, --pause, --quiet, --recursive, --rename, --replace, --scan, --scan-raw, --subdirs, --target, --type, --undo, inputs
    --magic             print a magic-number detection report (260 signature formats) and exit
    --scan-raw DEVICE   scan a raw device or disk image (260 signatures); dry-run report, --mode=copy carves fragments
    --scan FSFORMAT     scan a raw device/image for partitions (MBR/GPT + lost via filesystem signatures), then scan the selected filesystems for files/lost data; FORMATS: all,ntfs,exfat,fat12,fat16,fat32,ext,btrfs,xfs,reiserfs,hfs,swap,luks; dummy reports, copy carves to Target/FS-CARVE (V21)

TEMPLATE KEYWORDS (for --dirs / --subdirs/--rename/--extension/--dirs)
    accessed, created, day, exif-date, exif-datetime, exif-make, exif-model, exif-orientation, extension, format, format+size, id3-album, id3-artist, id3-genre, id3-title, id3-track, id3-year, md5sum, mime, mime-main, mime-sub, modified, month, name, random, sha1sum, sha224sum, sha256sum, sha384sum, sha512sum, size, size+format, title, year, year+month, year+month+day
    (segments join with '/'; unknown words are literal folder text)

ALWAYS AVAILABLE
    -h / --help          this usage
    --self-test          engine self test
    --version            version banner

OUT OF SCOPE FOR THIS EDITION (stripped; see README.md)
    --decompress: archive decompress (--decompress) - stripped; --delete: delete mode - use --mode=remove; --exif: EXIF rename/strip levels (--exif) - stripped; --needed: dependency listing - stripped; --noconfirm: interactive confirm - stripped; --non-interactive: interactive confirm - stripped; --stats: stats mode (--stats) - stripped; --strip: metadata stripping (--strip) - stripped; --title: metadata title rename (--title) - stripped; --verbose: verbose flag - use default output; --version: --version
"""


def _era_error(msg):
    print("Sort-V22 edition error: " + msg)
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
    # --magic (V17.5): magic-number detection report, then exit
    if "--magic" in argv:
        inputs = [a for a in argv if not a.startswith("-")]
        if not inputs:
            print("Nothing to inspect.")
            return 1
        for item in inputs:
            p = Path(item)
            if p.is_dir():
                print(f"{p} (directory - use --recursive not needed; listing files)")
                for child in sorted(p.iterdir()):
                    if child.is_file():
                        print(magic_report(child))
            elif p.exists():
                print(magic_report(p))
            else:
                print(f"{p}: not found")
        return 0
    allowed = set(EDITION["flags"]) | {"--self-test", "--version"}
    for a in argv:
        if a in ("-h", "--help"):
            print(_ERA_USAGE)
            return 0
        if a == "--self-test" or a == "--version" or not a.startswith("-"):
            continue
        name = a.split("=")[0].lower()
        if name == "--scan-raw":
            continue
        if name == "--scan":
            continue
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
