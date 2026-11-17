# Sort — Version 15.1

> Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

| | |
|---|---|
| **Version** | 15.1 |
| **Era** | V15.x — Modular library era |
| **Source** | B5 `zL2Zk5Ny` |
| **Size** | 183 lines |
| **Role** | Former main script — the root `Sort.sh` has since evolved into the threaded V16.0 edition |
| **Preceded by** | V15.0 |
| **Followed by** | V16.0 |

## About this version

Modular edition: the main script sources helper functions from a FUNCTIONS/*.sh library directory.

## Notes

- Modular lib, most developed
- The original `FUNCTIONS/` library was never uploaded; it has been rebuilt
  at the repository root ([FUNCTIONS/](../../FUNCTIONS/)) as a thin adapter
  layer over the modern `functions/` toolkit. This copy sources it from
  `../../FUNCTIONS/`.

## Usage

```bash
chmod +x Sort-V15.1.sh
./Sort-V15.1.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V15.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V15.1.pas
./Sort-V15.1
```
