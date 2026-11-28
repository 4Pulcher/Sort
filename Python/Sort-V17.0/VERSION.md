# VERSION.md - Sort V17.0 (Python)

## About

A comparison with **all 92 lineage versions** was made and every
functionality from V1.0–V15.1 is merged in, with all needed functions
embedded (11 modules inlined — no external library needed). Modes
Print/Copy/Move/Remove/Trash/Shred, dynamic values for `--dirs=`,
`--subdirs=`, `--rename=`, `--extension=` (dates, mime, checksums, random,
size, format tiers, duration, camera, exifdate, title), `--type=` filtering,
`--target=`, `--log=`, `--undo[=FILE]`, `--pause=`, `--hidden/--links/--recursive`,
threading via `--jobs=N`, and the init-system that proposes installing missing
tools on first use.

| Version | Language | Era | Source |
|---|---|---|---|
| V17.0 | Python | V17.x — self-contained rewrite | Rewrite commit `6811f9a` (mime case fix `bdbf63b`) |

## Changes

- Fully standalone: copy this single file anywhere and it runs.
- Destructive modes act on the file at the **calculated TARGET path** and
- The root [Sort.sh](../../Sort.sh) is kept identical to this version.

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
