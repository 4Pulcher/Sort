# Sort — Version 1.2

> The earliest "Ejder-scripts" organizer: a compact mode-driven sorter (Replace/Move/Copy/Add, Rename, SubDirs, Classes, Sizes) that walks files recursively, reads MIME via file(1), and renames by SHA256 or keeps names.

| | |
|---|---|
| **Version** | 1.2 |
| **Era** | V1.x — Ejder-scripts era |
| **Source** | B3 `ynxCdE27` |
| **Size** | 162 lines |
| **Preceded by** | V1.1 |
| **Followed by** | V1.3 |

## About this version

The earliest "Ejder-scripts" organizer: a compact mode-driven sorter (Replace/Move/Copy/Add, Rename, SubDirs, Classes, Sizes) that walks files recursively, reads MIME via file(1), and renames by SHA256 or keeps names.

## Notes

- Small refinements

## Usage

```bash
chmod +x Sort-V1.2.sh
./Sort-V1.2.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V1.2.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V1.2.pas
./Sort-V1.2
```
