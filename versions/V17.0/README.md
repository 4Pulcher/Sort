# Sort — Version 17.0

> Self-contained edition: every functionality of the whole lineage merged into one file.

| | |
|---|---|
| **Version** | 17.0 |
| **Era** | V17.x — self-contained rewrite |
| **Source** | Rewrite commit `6811f9a` (mime case fix `bdbf63b`) |
| **Size** | 6025 lines |
| **Role** | Current main script — identical to the root `Sort.sh` |
| **Preceded by** | V16.1 |
| **Followed by** | — (last version) |

## About this version

A comparison with **all 92 lineage versions** was made and every
functionality from V1.0–V15.1 is merged in, with all needed functions
embedded (11 modules inlined — no external library needed). Modes
Print/Copy/Move/Remove/Trash/Shred, dynamic values for `--dirs=`,
`--subdirs=`, `--rename=`, `--extension=` (dates, mime, checksums, random,
size, format tiers, duration, camera, exifdate, title), `--type=` filtering,
`--target=`, `--log=`, `--undo[=FILE]`, `--pause=`, `--hidden/--links/--recursive`,
threading via `--jobs=N`, and the init-system that proposes installing missing
tools on first use.

## Notes

- Fully standalone: copy this single file anywhere and it runs.
- Destructive modes act on the file at the **calculated TARGET path** and
  refuse source = target; dry-run preview is the default.
- The root [Sort.sh](../../Sort.sh) is kept identical to this version.

## Usage

```bash
chmod +x Sort-V17.0.sh
./Sort-V17.0.sh --usage   # short reminder
./Sort-V17.0.sh --help    # full reference
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V17.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V17.0.pas
./Sort-V17.0
```
