# Sort — Version 9.2

> The safe-modes generation: explicit copy/move/remove/trash/shred modes, requirement checks, logging helpers, dry-run default.

| | |
|---|---|
| **Version** | 9.2 |
| **Era** | V9.x — Safe copy/move/remove modes |
| **Source** | B1 `INgaCYsg` |
| **Size** | 1674 lines |
| **Preceded by** | V9.1 |
| **Followed by** | V9.3 |

## About this version

The safe-modes generation: explicit copy/move/remove/trash/shred modes, requirement checks, logging helpers, dry-run default.

## Usage

```bash
chmod +x Sort-V9.2.sh
./Sort-V9.2.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V9.2.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V9.2.pas
./Sort-V9.2
```
