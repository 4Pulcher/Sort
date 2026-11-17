# Sort — Version 10.1

> The annotated "v2.2 + notes" generation: extensive inline documentation around the media-intelligent core.

| | |
|---|---|
| **Version** | 10.1 |
| **Era** | V10.x — Annotated era |
| **Source** | B5 `qffGVzmG` |
| **Size** | 793 lines |
| **Preceded by** | V10.0 |
| **Followed by** | V10.2 |

## About this version

The annotated "v2.2 + notes" generation: extensive inline documentation around the media-intelligent core.

## Usage

```bash
chmod +x Sort-V10.1.sh
./Sort-V10.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V10.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V10.1.pas
./Sort-V10.1
```
