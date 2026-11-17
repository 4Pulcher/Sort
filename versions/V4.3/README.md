# Sort — Version 4.3

> The "by Ali_ISIN" CamelCase generation: option parsing, MIME-based directory trees, image/video WxH detection, interrupt handling.

| | |
|---|---|
| **Version** | 4.3 |
| **Era** | V4.x — CamelCase era |
| **Source** | B1 `Aye8Yzn0` |
| **Size** | 250 lines |
| **Preceded by** | V4.2 |
| **Followed by** | V4.4 |

## About this version

The "by Ali_ISIN" CamelCase generation: option parsing, MIME-based directory trees, image/video WxH detection, interrupt handling.

## Notes

- Reduced variant

## Usage

```bash
chmod +x Sort-V4.3.sh
./Sort-V4.3.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V4.3.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V4.3.pas
./Sort-V4.3
```
