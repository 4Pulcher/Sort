# VERSION.md - Sort V17.1 (Python)

## About

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

| Version | Language | Era | Source |
|---|---|---|---|
| V17.1 | Python | V17.x — self-contained rewrite | V17.0 + built-in UI translation (`--lang=XX`) |

## Changes

- Fully standalone: copy this single file anywhere and it runs.
- Destructive modes act on the file at the **calculated TARGET path** and
- The root [Sort.sh](../../Sort.sh) is kept identical to this version.

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
