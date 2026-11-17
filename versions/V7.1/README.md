# Sort — Version 7.1

> A two-file side branch with readonly-declared sections and refined ZERO-handling.

| | |
|---|---|
| **Version** | 7.1 |
| **Era** | V7.x — Readonly-sections pair |
| **Source** | B2 `FnzWHFNE` |
| **Size** | 510 lines |
| **Preceded by** | V7.0 |
| **Followed by** | V8.0 |

## About this version

A two-file side branch with readonly-declared sections and refined ZERO-handling.

## Notes

- ZERO-handling refinement

## Usage

```bash
chmod +x Sort-V7.1.sh
./Sort-V7.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V7.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V7.1.pas
./Sort-V7.1
```
