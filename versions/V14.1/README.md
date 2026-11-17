# Sort — Version 14.1

> The "Safe Transport Engine" side branch: transport-focused safe copy/move with verification.

| | |
|---|---|
| **Version** | 14.1 |
| **Era** | V14.x — Safe Transport Engine |
| **Source** | B6 `oRfRsiOr` |
| **Size** | 668 lines |
| **Preceded by** | V14.0 |
| **Followed by** | V15.0 |

## About this version

The "Safe Transport Engine" side branch: transport-focused safe copy/move with verification.

## Notes

- Twin/refinement

## Usage

```bash
chmod +x Sort-V14.1.sh
./Sort-V14.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V14.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V14.1.pas
./Sort-V14.1
```
