# Sort V20 - Bash edition

V20 adds `--scan-raw`: signature-based scanning of a **raw block device or
disk image** (`--scan-raw /dev/sdb`, `--scan-raw disk.img`). The 237-entry
magic table already used by `--magic` is reused to find known file formats
at **any byte offset**, including files that are no longer reachable through
the filesystem (lost data, deleted files, damaged partitions).

| | |
|---|---|
| **Version** | V20 |
| **Language** | SHELL (Bash edition) |
| **Era** | - |
| **Source** | - |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

## Build / run

`chmod +x Sort-V20.sh && ./Sort-V20.sh (bash 4+)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
