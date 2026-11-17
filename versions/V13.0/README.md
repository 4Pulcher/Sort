# Sort — Version 13.0

> Fully commented, media-intelligent edition with per-block documentation throughout.

| | |
|---|---|
| **Version** | 13.0 |
| **Era** | V13.x — Commented edition |
| **Source** | B6 `HxoiXiB3` |
| **Size** | 1197 lines |
| **Discarded internal label** | `v3.0` |
| **Preceded by** | V12.3 |
| **Followed by** | V13.1 |

## About this version

Fully commented, media-intelligent edition with per-block documentation throughout.

## Notes

- "Media-Intelligent" v3.0 (label discarded)

## Usage

```bash
chmod +x Sort-V13.0.sh
./Sort-V13.0.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V13.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V13.0.pas
./Sort-V13.0
```
