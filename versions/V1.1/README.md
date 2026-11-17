# Sort — Version 1.1

> The earliest "Ejder-scripts" organizer: a compact mode-driven sorter (Replace/Move/Copy/Add, Rename, SubDirs, Classes, Sizes) that walks files recursively, reads MIME via file(1), and renames by SHA256 or keeps names.

| | |
|---|---|
| **Version** | 1.1 |
| **Era** | V1.x — Ejder-scripts era |
| **Source** | B3 `pM2LoSXZ` |
| **Size** | 160 lines |
| **Preceded by** | V1.0 |
| **Followed by** | V1.2 |

## About this version

The earliest "Ejder-scripts" organizer: a compact mode-driven sorter (Replace/Move/Copy/Add, Rename, SubDirs, Classes, Sizes) that walks files recursively, reads MIME via file(1), and renames by SHA256 or keeps names.

## Notes

- +1 line drift from V1.0

## Usage

```bash
chmod +x Sort-V1.1.sh
./Sort-V1.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V1.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V1.1.pas
./Sort-V1.1
```
