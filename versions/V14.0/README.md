# Sort — Version 14.0

> The "Safe Transport Engine" side branch: transport-focused safe copy/move with verification.

| | |
|---|---|
| **Version** | 14.0 |
| **Era** | V14.x — Safe Transport Engine |
| **Source** | B3 `noXNl312` |
| **Size** | 705 lines |
| **Preceded by** | V13.1 |
| **Followed by** | V14.1 |

## About this version

The "Safe Transport Engine" side branch: transport-focused safe copy/move with verification.

## Usage

```bash
chmod +x Sort-V14.0.sh
./Sort-V14.0.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V14.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V14.0.pas
./Sort-V14.0
```
