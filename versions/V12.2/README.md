# Sort — Version 12.2

> Threaded generations: background worker subshells with job throttling, centralized Log_Print logging, optional logfile, TUI dashboard.

| | |
|---|---|
| **Version** | 12.2 |
| **Era** | V12.x — Threaded generations |
| **Source** | B5 `fZBTJLmO` |
| **Size** | 969 lines |
| **Discarded internal label** | `v5.1 (Threadded, Loggging, Displayed)` |
| **Preceded by** | V12.1 |
| **Followed by** | V12.3 |

## About this version

Threaded generations: background worker subshells with job throttling, centralized Log_Print logging, optional logfile, TUI dashboard.

## Notes

- "Threadded, Loggging, Displayed"

## Usage

```bash
chmod +x Sort-V12.2.sh
./Sort-V12.2.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V12.2.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V12.2.pas
./Sort-V12.2
```
