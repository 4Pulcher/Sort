# Sort — Version 5.5

> The Media-Intelligent mainline: rich option set (--dirs/--subdirs/--rename/--extension/--title/--pause), MIME + media metadata paths, built-in help heredoc.

| | |
|---|---|
| **Version** | 5.5 |
| **Era** | V5.x — Media-Intelligent mainline |
| **Source** | B2 `Dm9va8CU` |
| **Size** | 499 lines |
| **Preceded by** | V5.4 |
| **Followed by** | V5.6 |

## About this version

The Media-Intelligent mainline: rich option set (--dirs/--subdirs/--rename/--extension/--title/--pause), MIME + media metadata paths, built-in help heredoc.

## Usage

```bash
chmod +x Sort-V5.5.sh
./Sort-V5.5.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V5.5.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V5.5.pas
./Sort-V5.5
```
