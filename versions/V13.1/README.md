# Sort — Version 13.1

> Fully commented, media-intelligent edition with per-block documentation throughout.

| | |
|---|---|
| **Version** | 13.1 |
| **Era** | V13.x — Commented edition |
| **Source** | B2 `njoWkAuw` |
| **Size** | 1254 lines |
| **Preceded by** | V13.0 |
| **Followed by** | V14.0 |

## About this version

Fully commented, media-intelligent edition with per-block documentation throughout.

## Notes

- Successor, most developed

## Usage

```bash
chmod +x Sort-V13.1.sh
./Sort-V13.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V13.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V13.1.pas
./Sort-V13.1
```
