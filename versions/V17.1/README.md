# Sort — Version 17.1

> The self-contained edition, now speaking 20 languages.

| | |
|---|---|
| **Version** | 17.1 |
| **Era** | V17.x — self-contained rewrite |
| **Source** | V17.0 + built-in UI translation (`--lang=XX`) |
| **Size** | 8694 lines (.sh) |
| **Role** | Current main script — identical to the root `Sort.sh` |
| **Preceded by** | V17.0 |
| **Followed by** | — (last version) |

## About this version

Everything from V17.0 (all lineage features merged, 11 modules inlined,
threading, dynamic values, archives, EXIF, init-system) plus a new
**`--lang=XX` option**: the complete user interface — usage, help, prompts,
errors, warnings, info lines and the summary — is built into the script in
**20 languages**, no external translation files needed:

```
en  zh  hi  es  fr  ar  bn  pt  ru  ur
id  de  ja  tr  ko  vi  it  pl  nl  fa
```

- Default language: `en` (English) — zero overhead, strings pass through untouched
- `--lang=XX` selects the UI language for this run; `--lang` (bare) prints the
  language list with native names
- An unsupported code is rejected with the list of valid languages
- Example command lines, keyword lists and hash names stay literal by design
- The FreePascal port (`Sort-V17.1.pas`) carries the same 20-language UI via
  its own `Tr`/`Tf` translation layer

## Notes

- Fully standalone: copy this single file anywhere and it runs.
- Destructive modes act on the file at the **calculated TARGET path** and
  refuse source = target; dry-run preview is the default.
- The root [Sort.sh](../../Sort.sh) is kept identical to this version.

## Usage

```bash
chmod +x Sort-V17.1.sh
./Sort-V17.1.sh --lang          # language list
./Sort-V17.1.sh --lang=de --help
./Sort-V17.1.sh --lang=tr --mode=move --dirs=year+month ~/Pics
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V17.1.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V17.1.pas
./Sort-V17.1
```

NB/This code is not tested yet! — the port could not be compiled inside the
build sandbox (no FPC compiler available); please verify locally.
