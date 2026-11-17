# Sort — Version 16.0

> Threaded, colored rewrite: a thin driver over the `functions/` toolkit.

| | |
|---|---|
| **Version** | 16.0 |
| **Era** | V16.x — `functions/` library rewrite |
| **Source** | Rewrite commit `a071fdd` |
| **Size** | 495 lines |
| **Role** | First rewrite of the mainline onto the isolated `functions/` toolkit |
| **Preceded by** | V15.1 |
| **Followed by** | V16.1 |

## About this version

Complete rewrite of the Sort mainline as a driver over the `functions/` library
at the repository root: it collects every file to treat into an array up front,
classifies each file by MIME type / size, and processes the array through a
bounded pool of background jobs (threading). Verbose by default, colored
output via `--colored`, dry-run preview by default.

## Notes

- First version built on the modular `functions/` toolkit (deps, colors, file,
  mime, hash, imagemagick, ffmpeg).
- Introduced `--jobs=N` threading, status tags (COPIED/MOVED/PREVIEW/SKIPPED/FAILED)
  and automatic `~(N)` collision names.
- This copy loads the library from `../../functions/` so it runs from its
  version folder; it needs the repository tree around it.

## Usage

```bash
chmod +x Sort-V16.0.sh
./Sort-V16.0.sh           # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V16.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V16.0.pas
./Sort-V16.0
```
