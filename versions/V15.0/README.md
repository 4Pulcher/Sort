# Sort — Version 15.0

> Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

| | |
|---|---|
| **Version** | 15.0 |
| **Era** | V15.x — Modular library era |
| **Source** | B2 `oztrmyOi` |
| **Size** | 21 lines |
| **Preceded by** | V14.1 |
| **Followed by** | V15.1 |

## About this version

Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

## Notes

- Sources `FUNCTIONS/*.sh`

## Usage

```bash
chmod +x Sort-V15.0.sh
./Sort-V15.0.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V15.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V15.0.pas
./Sort-V15.0
```
