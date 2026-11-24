# Sort.py - the Python edition of the Sort lineage

A single-file, **standard-library-only** Python implementation of the complete
Bash `Sort.sh` lineage (V1.0 - V17.3). No `file`, no ImageMagick, no FFmpeg,
no ExifTool, no pip packages: MIME sniffing, media dimensions, hashing and
text detection are all native. Runs on Debian with just the `python3` package
(main repo; nothing needed from contrib/non-free).

```bash
python3 Sort.py --self-test                # built-in test suite (23 checks)
python3 Sort.py --dirs=mime-main --type=image Downloads/*   # dry run by default
python3 Sort.py --mode=move --dirs=year+month Videos/
python3 Sort.py --mode=copy --rename=sha256sum *.jpg
python3 Sort.py --mode=trash --recursive --type=archive Downloads/
python3 Sort.py --mode=move --log actions.jsonl ...
python3 Sort.py --undo actions.jsonl
```

## Modes

| Mode | Behaviour | Lineage origin |
|---|---|---|
| `dummy` (default) | dry run: prints every destination, changes nothing | V9 safe-modes era |
| `copy` / `move` | organize into the target tree; empty source dirs cleaned | V1.x+, cleanup from V10.2 |
| `remove` | delete (with empty-dir cleanup) | V9.x |
| `trash` | freedesktop XDG trash with `.trashinfo` | V14 Safe Transport |
| `shred` | 3-pass random overwrite then delete | V14 |

## Feature map: Bash version -> where it lives in Sort.py

| Bash era | Feature | Python location |
|---|---|---|
| V1.x-V4.x | organize flow, MIME keywords, template destination paths | `Organizer.run/process`, `TemplateEngine` |
| V5.x | Media-Intelligent renames: hash/size/format keywords | `hash_file`, `decimal_size_label`, `keyword_value` |
| V6.x | single-pass mode parsing, type filters | `TYPE_FILTERS`, `matches_filter` |
| V7-V8 | source/target argument model, per-file templates | CLI `--target`, per-file `resolve` |
| V9.x | safe copy/move/remove, dry-run default, self-tests | default `dummy` mode, `run_self_test` |
| V9.3 | path/name/extension context awareness | `TemplateEngine(context=...)` |
| V9.5 | `Resolve_Value` prefixes & fallbacks | `segment()`: `lower:` `upper:` `raw:`, `k1\|k2` |
| V10.x | MIME main/sub model, emoji icons, empty-dir cleanup | `sniff_mime`, `ICONS`, `_cleanup_empty` |
| V11.0 | fully self-contained single-file edition | the whole file |
| V12.x | threaded worker pool | `--jobs` via `ThreadPoolExecutor` |
| V13.x | stable, heavily documented generation | docstrings/MANPAGE |
| V14-V15 | Safe Transport (trash/shred) and undo log | `freedesktop_trash`, `shred_file`, `undo_log` |
| V16-V17 | template language extensions, slugified names | `slugify`, `segment` |
| V17.1 | multilingual UI (compact: en, nl, fr, de, tr) | `TRANSLATIONS`, `--lang` |

## Intentional deltas (stdlib-only constraint)

* Deep media tags from the Bash V17 era that required ExifTool/FFmpeg
  (EXIF camera fields, audio artist/title, video stream data) are **not**
  ported; only native capabilities are kept: magic-byte MIME sniffing and
  PNG/GIF/BMP/JPEG/WEBP dimension parsing (orientation/tier labels).
* The Bash `--pause` option remains but millisecond pacing in threads is
  cooperative, not wall-clock exact.
* `remove`/`shred` actions are logged but cannot be undone by design;
  `undo` reverses `copy`/`move`/`trash`.

## Requirements

* Python 3.9+ (Debian: `python3`, main repository). No third-party modules.
