# Sort — Version 6.18

> The "Optimized" generation: progress counters, colored TUI output, Draw_Line banners, MAX_JOBS throttling, mode combined into --mode=.

| | |
|---|---|
| **Version** | 6.18 |
| **Era** | V6.x — Optimized lineage |
| **Source** | B5 `PMFBCCS9` |
| **Size** | 626 lines |
| **Preceded by** | V6.17 |
| **Followed by** | V6.19 |

## About this version

The "Optimized" generation: progress counters, colored TUI output, Draw_Line banners, MAX_JOBS throttling, mode combined into --mode=.

## Usage

```bash
chmod +x Sort-V6.18.sh
./Sort-V6.18.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V6.18.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V6.18.pas
./Sort-V6.18
```
