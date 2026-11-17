# Sort — Version 2.7

> Small standalone prototypes, each exploring one idea (extension sorting, size buckets, FindImages, SortSize). Rough, experimental code.

| | |
|---|---|
| **Version** | 2.7 |
| **Era** | V2.x — Prototype micro-scripts |
| **Source** | B5 `BkpNmEzd` |
| **Size** | 44 lines |
| **Preceded by** | V2.6 |
| **Followed by** | V2.8 |

## About this version

Small standalone prototypes, each exploring one idea (extension sorting, size buckets, FindImages, SortSize). Rough, experimental code.

## Usage

```bash
chmod +x Sort-V2.7.sh
./Sort-V2.7.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V2.7.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V2.7.pas
./Sort-V2.7
```
