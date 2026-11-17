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

## Caution — test phase

⚠ **Be careful with this script.** NB/This code is in a **test phase** — not
tested yet: every version was reconstructed from the uploaded lineage and passes
`bash -n`, but always try it on a scratch copy of a few files first.

- Run it **without arguments** first: every version carries a built-in usage menu.
- Later editions preview every action (dry-run) before anything is touched —
  read the preview before confirming.

## Examples

```bash
# 1) bare run — the built-in usage menu
./Sort-V15.1.sh

# 2) test fase — try it on a scratch copy first (non-destructive)
mkdir -p /tmp/sort-test && cp ~/Pictures/a.jpg ~/Documents/b.pdf /tmp/sort-test/
cd /tmp/sort-test
/path/to/Sort-V15.1.sh --copy .

```

## About the author

The Sort scripts are written by **HEjder** — Ali ISIN, writing under the nickname
**Ejder / HEjder**. Every script in this repository is a HEjder edition: syntax
errors corrected, formatting unified, every function commented, and each one ends
with `Thanks for using HEjder scripts!`.

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

---

## Appendix — the same text in the top 5 alphabets

Caution, explanation, example and author — the same English words, rendered
phonetically in the top 5 symbol systems, one after the other (the example
command stays runnable in all of them).

**English (Latin alphabet)**

Sort 15.1 — sort, rename and organize your files. Caution: be careful with this script, understand it before you use it, especially the remove, trash and shred modes. Example: ./Sort-V15.1.sh — Author: HEjder

**中文符号 (Han symbols)**

索特 15.1 — 索特、雷内姆 安徳 奥根奈兹 尤尔 法伊尔斯。凯申：比 凯尔富 威兹 迪斯 斯克里普特，安德斯坦德 伊特 比福 尤 尤兹 伊特，埃斯佩谢利 泽 雷穆夫、特拉什 安徳 什雷德 穆兹。埃克桑普尔：./Sort-V15.1.sh — 奥瑟：海杰德

**देवनागरी (Devanagari)**

सॉर्ट 15.1 — सॉर्ट, रिनेम ऍण्ड ऑर्गनाइझ युअर फाइल्स. कॉशन: बी केअरफुल विथ दिस स्क्रिप्ट, अंडरस्टैंड इट बिफोर यू यूज़ इट, एस्पेशियली द रिमूव, ट्रॅश ऍण्ड श्रेड मोड्स. इग्ज़ाम्पल: ./Sort-V15.1.sh — ऑथर: हेजडेर

**Кириллица (Cyrillic)**

Сорт 15.1 — сорт, ринейм энд органайз ёр файлс. Кэйшн: би кэрефул уиз зис скрипт, андэстенд ит бифор ю юз ит, эспешали зе римув, трэш энд шред моудс. Экзампл: ./Sort-V15.1.sh — Атор: Хейдер

**العربية (Arabic)**

سورت 15.1 — سورت، رينيم أند أورغنايز يور فايلز. كيوشن: بي كيرفول ويذ ذيس سكريبت، أندرستند إت بيفور يو يوز إت، إسبشالي ذا ريموف، تراش أند شرد موودز. إكزامبل: ./Sort-V15.1.sh — أوثور: هيدجر
