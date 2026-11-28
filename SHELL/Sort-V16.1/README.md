# Sort V16.1 - Bash edition

V16.0 with the complete `functions/` map loaded (system, ui, exif, docs, core
added on top). New options: `--exif` (`<Camera>/<YYYY-MM-DD>` levels),
`--strip` (remove EXIF/GPS from targets), `--rename=title` / `--title`
(rename by internal PDF/audio/video titles), interrupt handling via the system
module's `Break` trap and a `Draw_Line '='` banner.

| | |
|---|---|
| **Version** | V16.1 |
| **Language** | SHELL (Bash edition) |
| **Era** | V16.x — `functions/` library rewrite |
| **Source** | Rewrite commit `6d13ab3` |
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

`chmod +x Sort-V16.1.sh && ./Sort-V16.1.sh (bash 4+)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
