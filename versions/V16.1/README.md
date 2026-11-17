# Sort — Version 16.1

> Full `functions/` library in use: EXIF, titles, strip, docs and system helpers added.

| | |
|---|---|
| **Version** | 16.1 |
| **Era** | V16.x — `functions/` library rewrite |
| **Source** | Rewrite commit `6d13ab3` |
| **Size** | 584 lines |
| **Role** | Extended rewrite — all 12 `functions/` modules loaded |
| **Preceded by** | V16.0 |
| **Followed by** | V17.0 |

## About this version

V16.0 with the complete `functions/` map loaded (system, ui, exif, docs, core
added on top). New options: `--exif` (`<Camera>/<YYYY-MM-DD>` levels),
`--strip` (remove EXIF/GPS from targets), `--rename=title` / `--title`
(rename by internal PDF/audio/video titles), interrupt handling via the system
module's `Break` trap and a `Draw_Line '='` banner.

## Notes

- Uses exiftool-backed EXIF routing with graceful degradation when the tools
  are missing.
- This copy loads the library from `../../functions/` so it runs from its
  version folder; it needs the repository tree around it.
- Superseded by V17.0, which embeds all functionality in one self-contained file.

## Usage

```bash
chmod +x Sort-V16.1.sh
./Sort-V16.1.sh           # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V16.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V16.1.pas
./Sort-V16.1
```
