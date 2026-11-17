# Sort — Version 12.1

> Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

| | |
|---|---|
| **Version** | 12.1 |
| **Era** | V15.x — Modular library era |
| **Source** | `Ec5sYTHY` |
| **Size** | Two `}` written where `fi` expected (lines 129, 441); `]` instead of `done` at line 517 lines |
| **Discarded internal label** | `v5 (Threadded and Logging)` |
| **Preceded by** | V12.0 |
| **Followed by** | V12.2 |

## About this version

Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

## Notes

- All three corrected

## Fixes applied (HEjder edition)

Two `}` tokens written where `fi` was expected corrected; a `]` instead of `done` corrected.

## Usage

```bash
chmod +x Sort-V12.1.sh
./Sort-V12.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V12.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V12.1.pas
./Sort-V12.1
```
