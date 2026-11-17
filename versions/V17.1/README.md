# Sort — Version 17.1

> The self-contained edition, now speaking 20 languages.

| | |
|---|---|
| **Version** | 17.1 |
| **Era** | V17.x — self-contained rewrite |
| **Source** | V17.0 + built-in UI translation (`--lang=XX`) |
| **Size** | 8694 lines (.sh) |
| **Role** | Previous main script — superseded by V17.2 (performance edition) |
| **Preceded by** | V17.0 |
| **Followed by** | V17.2 (performance edition) |

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

## Caution — test phase

⚠ **Be careful with this script.** NB/This code is in a **test phase** — not
tested yet: every version was reconstructed from the uploaded lineage and passes
`bash -n`, but always try it on a scratch copy of a few files first. The destructive modes in this version are: `--remove`, `--delete`, `--trash`, `--shred` — they do what they say.

- Run it **without arguments** first: every version carries a built-in usage menu.
- Later editions preview every action (dry-run) before anything is touched —
  read the preview before confirming.

## Examples

```bash
# 1) bare run — the built-in usage menu
./Sort-V17.1.sh

# 2) test fase — try it on a scratch copy first (non-destructive)
mkdir -p /tmp/sort-test && cp ~/Pictures/a.jpg ~/Documents/b.pdf /tmp/sort-test/
cd /tmp/sort-test
/path/to/Sort-V17.1.sh --mode=copy --recursive --jobs=2 --colored .

# 3) move variant — check the built-in menu for all mode words
/path/to/Sort-V17.1.sh --mode=move --recursive ~/Pictures/2Sort
```

## About the author

The Sort scripts are written by **HEjder** — Ali ISIN, writing under the nickname
**Ejder / HEjder**. Every script in this repository is a HEjder edition: syntax
errors corrected, formatting unified, every function commented, and each one ends
with `Thanks for using HEjder scripts!`.

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

---

## Appendix — the same text in the top 5 alphabets

Caution, explanation, example and author — the same English words, rendered
phonetically in the top 5 symbol systems, one after the other (the example
command stays runnable in all of them).

**English (Latin alphabet)**

Sort 17.1 — sort, rename and organize your files. Caution: be careful with this script, understand it before you use it, especially the remove, trash and shred modes. Example: ./Sort-V17.1.sh — Author: HEjder

**中文符号 (Han symbols)**

索特 17.1 — 索特、雷内姆 安徳 奥根奈兹 尤尔 法伊尔斯。凯申：比 凯尔富 威兹 迪斯 斯克里普特，安德斯坦德 伊特 比福 尤 尤兹 伊特，埃斯佩谢利 泽 雷穆夫、特拉什 安徳 什雷德 穆兹。埃克桑普尔：./Sort-V17.1.sh — 奥瑟：海杰德

**देवनागरी (Devanagari)**

सॉर्ट 17.1 — सॉर्ट, रिनेम ऍण्ड ऑर्गनाइझ युअर फाइल्स. कॉशन: बी केअरफुल विथ दिस स्क्रिप्ट, अंडरस्टैंड इट बिफोर यू यूज़ इट, एस्पेशियली द रिमूव, ट्रॅश ऍण्ड श्रेड मोड्स. इग्ज़ाम्पल: ./Sort-V17.1.sh — ऑथर: हेजडेर

**Кириллица (Cyrillic)**

Сорт 17.1 — сорт, ринейм энд органайз ёр файлс. Кэйшн: би кэрефул уиз зис скрипт, андэстенд ит бифор ю юз ит, эспешали зе римув, трэш энд шред моудс. Экзампл: ./Sort-V17.1.sh — Атор: Хейдер

**العربية (Arabic)**

سورت 17.1 — سورت، رينيم أند أورغنايز يور فايلز. كيوشن: بي كيرفول ويذ ذيس سكريبت، أندرستند إت بيفور يو يوز إت، إسبشالي ذا ريموف، تراش أند شرد موودز. إكزامبل: ./Sort-V17.1.sh — أوثور: هيدجر
