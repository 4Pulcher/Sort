# Sort V16.1 - FreePascal edition

V16.0 with the complete `functions/` map loaded (system, ui, exif, docs, core
added on top). New options: `--exif` (`<Camera>/<YYYY-MM-DD>` levels),
`--strip` (remove EXIF/GPS from targets), `--rename=title` / `--title`
(rename by internal PDF/audio/video titles), interrupt handling via the system
module's `Break` trap and a `Draw_Line '='` banner.

| | |
|---|---|
| **Version** | V16.1 |
| **Language** | FreePascal (FreePascal edition) |
| **Era** | V16.x — `functions/` library rewrite |
| **Source** | Rewrite commit `6d13ab3` |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

## Build / run

`fpc -Mobjfpc -Sh Sort-VV16.1.pas`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
