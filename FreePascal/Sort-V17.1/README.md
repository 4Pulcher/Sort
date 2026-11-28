# Sort V17.1 - FreePascal edition

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

| | |
|---|---|
| **Version** | V17.1 |
| **Language** | FreePascal (FreePascal edition) |
| **Era** | V17.x — self-contained rewrite |
| **Source** | V17.0 + built-in UI translation (`--lang=XX`) |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

- Without `--mode` the tool only **previews** (dry run); nothing is touched.
- `--mode=remove`, `trash` and `shred` act on the calculated TARGET and are
  destructive: `shred` overwrites before deleting, making recovery impossible
  even with carving tools. Keep backups.
- Linux/macOS only: trash, shred and raw device scans rely on POSIX paths
  and tools (Windows: use WSL or MSYS2).
- `--decompress` unpacks archives into a temp dir first: beware zip bombs and
  very large archives filling `/tmp`.

## Build / run

`fpc -Mobjfpc -Sh Sort-V17.1.pas (FreePascal 3.2.2)`


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
