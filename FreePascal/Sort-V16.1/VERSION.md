# VERSION.md - Sort V16.1 (FreePascal)

## About

V16.0 with the complete `functions/` map loaded (system, ui, exif, docs, core
added on top). New options: `--exif` (`<Camera>/<YYYY-MM-DD>` levels),
`--strip` (remove EXIF/GPS from targets), `--rename=title` / `--title`
(rename by internal PDF/audio/video titles), interrupt handling via the system
module's `Break` trap and a `Draw_Line '='` banner.

| Version | Language | Era | Source |
|---|---|---|---|
| V16.1 | FreePascal | V16.x — `functions/` library rewrite | Rewrite commit `6d13ab3` |

## Changes

- Uses exiftool-backed EXIF routing with graceful degradation when the tools
- This copy loads the library from `../../functions/` so it runs from its
- Superseded by V17.0, which embeds all functionality in one self-contained file.

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
