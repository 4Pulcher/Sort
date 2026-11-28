# VERSION.md - Sort V18 (SHELL)

## About

V18 adds the fourth language to the family: a single-file, dependency-free
**C++17** edition (`Sort-V18.cpp`), alongside the usual Bash, FreePascal
and Python trio. All four editions now implement the same feature union,
including the full 237-signature `--magic` detection table inherited from
V17.5.

| Version | Language | Era | Source |
|---|---|---|---|
| V18 | SHELL | - | - |

## Changes

- `Sort-V18.cpp` - a pure C++17 port of `Sort-V18.py`:
- one file, standard library only: no `file`, no ImageMagick, no FFmpeg,
- native MIME sniffing, image dimensions (PNG/GIF/BMP/WEBP/JPEG),
- all six modes: dummy (default dry run), copy, move, remove, trash
- `--jobs` thread pool, JSONL `--log` and `--undo`, `--type` filters,
- the identical 237-signature `--magic` report (byte-for-byte the same
- era gate matching the Python edition: same allowed modes, flags and
- `--self-test` with the same 23 checks as `Sort-V18.py`
- Version bump: the Bash, FreePascal and Python editions are re-badged

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
