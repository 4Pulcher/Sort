# Sort — Version 11.0

> The version published on GitHub as Sort.sh (self-labeled v2.2): merge of the mainline --title support and the Optimized --jobs worker pool.

| | |
|---|---|
| **Version** | 11.0 |
| **Era** | V11.x — GitHub mainline |
| **Source** | **GitHub `./Sort`** |
| **Size** | 757 lines |
| **Role** | Published on GitHub as `Sort.sh` (the previous main script) |
| **Discarded internal label** | `v2.2` |
| **Preceded by** | V10.2 |
| **Followed by** | V12.0 |

## About this version

The version published on GitHub as Sort.sh (self-labeled v2.2): merge of the mainline --title support and the Optimized --jobs worker pool.

## Notes

- Self-labeled "v2.2"; merge of mainline `--title` + optimized `--jobs`; shares `Get_SHA_Keys` with V12.3

## Usage

```bash
chmod +x Sort-V11.0.sh
./Sort-V11.0.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V11.0.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V11.0.pas
./Sort-V11.0
```
