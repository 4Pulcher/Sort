# VERSION.md - Sort V20 (SHELL)

## About

V20 adds `--scan-raw`: signature-based scanning of a **raw block device or
disk image** (`--scan-raw /dev/sdb`, `--scan-raw disk.img`). The 237-entry
magic table already used by `--magic` is reused to find known file formats
at **any byte offset**, including files that are no longer reachable through
the filesystem (lost data, deleted files, damaged partitions).

| Version | Language | Era | Source |
|---|---|---|---|
| V20 | SHELL | - | - |

## Changes

- `--scan-raw PATH` (or `--scan-raw=PATH`), in every edition including the GUI:
- reads the device/image in 1 MiB blocks (with carry for signatures that
- format end rules: PNG chunk walk (IEND = exact), JPEG to FFD9, GIF to
- overlap suppression: an exact fragment owns its byte range; capped
- dummy mode (default): report only. copy mode: carves each fragment to
- refuses move/remove/trash/shred with
- JSONL log entry per carved fragment: `{"action": "carved",
- Output format is identical in all editions:
- Version bump: all editions re-badged from 19 to 20; the Qt6 GUI gains a

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
