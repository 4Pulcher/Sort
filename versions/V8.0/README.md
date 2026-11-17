# Sort — Version 8.0

> Source/target two-directory processing, ffprobe-based media inspection, deeper name collision handling.

| | |
|---|---|
| **Version** | 8.0 |
| **Era** | V8.x — Source/target era |
| **Source** | B1 `L6GJnT1y` |
| **Size** | 805 lines |
| **Preceded by** | V7.1 |
| **Followed by** | V8.1 |

## About this version

Source/target two-directory processing, ffprobe-based media inspection, deeper name collision handling.

## Usage

```bash
chmod +x Sort-V8.0.sh
./Sort-V8.0.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V8.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V8.0.pas
./Sort-V8.0
```
