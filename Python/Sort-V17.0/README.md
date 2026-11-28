# Sort V17.0 - Python edition

A comparison with **all 92 lineage versions** was made and every
functionality from V1.0–V15.1 is merged in, with all needed functions
embedded (11 modules inlined — no external library needed). Modes
Print/Copy/Move/Remove/Trash/Shred, dynamic values for `--dirs=`,
`--subdirs=`, `--rename=`, `--extension=` (dates, mime, checksums, random,
size, format tiers, duration, camera, exifdate, title), `--type=` filtering,
`--target=`, `--log=`, `--undo[=FILE]`, `--pause=`, `--hidden/--links/--recursive`,
threading via `--jobs=N`, and the init-system that proposes installing missing
tools on first use.

| | |
|---|---|
| **Version** | V17.0 |
| **Language** | Python (Python edition) |
| **Era** | V17.x — self-contained rewrite |
| **Source** | Rewrite commit `6811f9a` (mime case fix `bdbf63b`) |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

- Without `--mode` the tool only **previews** (dry run); nothing is touched.
- `--mode=remove`, `trash` and `shred` act on the calculated TARGET and are
  destructive: `shred` overwrites before deleting, making recovery impossible
  even with carving tools. Keep backups.
- Linux/macOS only: trash, shred and raw device scans rely on POSIX paths
  and tools (Windows: use WSL or MSYS2).
- `--decompress` unpacks archives into a temp dir first: beware zip bombs and
  very large archives filling `/tmp`.

## Build / run

`python3 Sort-V17.0.py (pure stdlib; --self-test verifies the engine)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
