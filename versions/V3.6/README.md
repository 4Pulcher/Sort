# Sort — Version 3.6

> Tiny launcher/wrapper scripts that call the main Sort script (e.g. 2Sort.sh) with preset options.

| | |
|---|---|
| **Version** | 3.6 |
| **Era** | V3.x — Launchers / wrappers |
| **Source** | B2 `dEtsPkbb` |
| **Size** | 18 lines |
| **Preceded by** | V3.5 |
| **Followed by** | V4.0 |

## About this version

Tiny launcher/wrapper scripts that call the main Sort script (e.g. 2Sort.sh) with preset options.

## Notes

- Most developed launcher

## Usage

```bash
chmod +x Sort-V3.6.sh
./Sort-V3.6.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V3.6.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V3.6.pas
./Sort-V3.6
```
