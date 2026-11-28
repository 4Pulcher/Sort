# VERSION.md - Sort V21 (Python)

## About

V21 adds `--scan=FSFormat`: whole-drive filesystem-partition scanning with
per-partition signature recovery. It reuses the V20 signature engine
(237 magic formats) inside every partition it finds.

| Version | Language | Era | Source |
|---|---|---|---|
| V21 | Python | - | - |

## Changes

- Phase 1 - partitions**: parses the MBR and GPT partition tables, then
- lost/deleted partitions** (ntfs, exfat, fat12/16/32, ext, btrfs, xfs,
- Phase 2 - recovery**: runs the V20 signature engine inside each
- Formats**: `all,ntfs,exfat,fat12,fat16,fat32,ext,btrfs,xfs,reiserfs,hfs,swap,luks`
- Output**: `dummy` (default) prints a report; `copy` carves fragments to
- Out of space**: on ENOSPC during copy you are prompted for a new target
- GUI (Sort-GUI.cpp)**: a new FS section with device + format fields, a

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
