# Sort — Version 8.5

> Source/target two-directory processing, ffprobe-based media inspection, deeper name collision handling.

| | |
|---|---|
| **Version** | 8.5 |
| **Era** | V8.x — Source/target era |
| **Source** | B2 `jk804O6l` |
| **Size** | 927 lines |
| **Preceded by** | V8.4 |
| **Followed by** | V8.6 |

## About this version

Source/target two-directory processing, ffprobe-based media inspection, deeper name collision handling.

## Notes

- Adds ffprobe

## Caution — test phase

⚠ **Be careful with this script.** NB/This code is in a **test phase** — not
tested yet: every version was reconstructed from the uploaded lineage and passes
`bash -n`, but always try it on a scratch copy of a few files first. Via `--mode=` this version can also reach replace/remove-style modes — check the built-in menu for the exact mode words.

- Run it **without arguments** first: every version carries a built-in usage menu.
- Later editions preview every action (dry-run) before anything is touched —
  read the preview before confirming.

## Examples

```bash
# 1) bare run — the built-in usage menu
./Sort-V8.5.sh

# 2) test fase — try it on a scratch copy first (non-destructive)
mkdir -p /tmp/sort-test && cp ~/Pictures/a.jpg ~/Documents/b.pdf /tmp/sort-test/
/path/to/Sort-V8.5.sh --mode=copy --source=/tmp/sort-test --target=/tmp/sorted

# 3) move variant — check the built-in menu for all mode words
/path/to/Sort-V8.5.sh --mode=move --recursive ~/Pictures/2Sort
```

## About the author

The Sort scripts are written by **HEjder** — Ali ISIN, writing under the nickname
**Ejder / HEjder**. Every script in this repository is a HEjder edition: syntax
errors corrected, formatting unified, every function commented, and each one ends
with `Thanks for using HEjder scripts!`.

## Usage

```bash
chmod +x Sort-V8.5.sh
./Sort-V8.5.sh          # run without arguments for the built-in usage menu
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V8.5.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V8.5.pas
./Sort-V8.5
```

---

## Appendix — the same text in the top 5 alphabets

Caution, explanation, example and author — the same English words, rendered
phonetically in the top 5 symbol systems, one after the other (the example
command stays runnable in all of them).

**English (Latin alphabet)**

Sort 8.5 — sort, rename and organize your files. Caution: be careful with this script, understand it before you use it, especially the remove, trash and shred modes. Example: ./Sort-V8.5.sh — Author: HEjder

**中文符号 (Han symbols)**

索特 8.5 — 索特、雷内姆 安徳 奥根奈兹 尤尔 法伊尔斯。凯申：比 凯尔富 威兹 迪斯 斯克里普特，安德斯坦德 伊特 比福 尤 尤兹 伊特，埃斯佩谢利 泽 雷穆夫、特拉什 安徳 什雷德 穆兹。埃克桑普尔：./Sort-V8.5.sh — 奥瑟：海杰德

**देवनागरी (Devanagari)**

सॉर्ट 8.5 — सॉर्ट, रिनेम ऍण्ड ऑर्गनाइझ युअर फाइल्स. कॉशन: बी केअरफुल विथ दिस स्क्रिप्ट, अंडरस्टैंड इट बिफोर यू यूज़ इट, एस्पेशियली द रिमूव, ट्रॅश ऍण्ड श्रेड मोड्स. इग्ज़ाम्पल: ./Sort-V8.5.sh — ऑथर: हेजडेर

**Кириллица (Cyrillic)**

Сорт 8.5 — сорт, ринейм энд органайз ёр файлс. Кэйшн: би кэрефул уиз зис скрипт, андэстенд ит бифор ю юз ит, эспешали зе римув, трэш энд шред моудс. Экзампл: ./Sort-V8.5.sh — Атор: Хейдер

**العربية (Arabic)**

سورت 8.5 — سورت، رينيم أند أورغنايز يور فايلز. كيوشن: بي كيرفول ويذ ذيس سكريبت، أندرستند إت بيفور يو يوز إت، إسبشالي ذا ريموف، تراش أند شرد موودز. إكزامبل: ./Sort-V8.5.sh — أوثور: هيدجر


---

## Python edition - Sort-VV8.5.py

This directory also carries **Sort-VV8.5.py**, a / standalone, standard-library-only
Python edition of the same version. It makes **no external calls at all**: no
`file`, `ffprobe`, `identify`, `exiftool`... - pure Python 3 (Debian `python3`).

* Same directory logic era as the Bash edition above (modes, options and
  template keywords are gated to what this era's Bash script supports; the
  allowed set is printed by `Sort-VV8.5.py -h`).
* Where the Bash edition depended on external tools, the Python edition
  implements the equivalent natively (checksums, MIME sniffing, image
  dimensions) - or **strips that option** when there is no native equivalent:
  none
* Usage: `python3 Sort-VV8.5.py --mode=dummy FILES...`
* Self check: `python3 Sort-VV8.5.py --self-test`
* Not portable to Python in this edition: nothing - the file is fully
  self-contained (the engine is embedded; no other files are imported).
