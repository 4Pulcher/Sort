# Sort V21 - Python edition

V21 adds `--scan=FSFormat`: whole-drive filesystem-partition scanning with
per-partition signature recovery. It reuses the V20 signature engine
(237 magic formats) inside every partition it finds.

| | |
|---|---|
| **Version** | V21 |
| **Language** | Python (Python edition) |
| **Era** | - |
| **Source** | - |
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
- `--scan-raw` / `--scan`: prefer a **read-only disk image** (`dd`, `ddrescue`)
  over a live `/dev/sdX`, and **never** write the carve `--target` onto the
  disk you are scanning - it would overwrite the very data you are recovering.
- Carved fragments without an end marker run to the carve cap (about 5 MiB);
  hits crossing a partition end are marked broken (overwritten data).

## Build / run

`python3 Sort-V21.py (pure stdlib; --self-test verifies the engine)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
