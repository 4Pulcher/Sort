# Sort — Version 17.2

> The self-contained edition, now speaking 20 languages — and up to ~30% faster.

| | |
|---|---|
| **Version** | 17.2 |
| **Era** | V17.x — self-contained rewrite |
| **Source** | V17.1 + performance edition (fewer forks per file) |
| **Size** | 8809 lines (.sh) |
| **Role** | Current main script — identical to the root `Sort.sh` |
| **Preceded by** | V17.1 |
| **Followed by** | — (last version) |

## About this version

Everything from V17.1 (all lineage features merged, 11 modules inlined,
threading, dynamic values, archives, EXIF, init-system, 20-language UI) plus a
**performance edition** — the number of external process spawns per file was
nearly halved, measured with a 2000-file benchmark in preview mode:

| Run | V17.1 | V17.2 |
|---|---|---|
| 2000 files, `--jobs=1` | 87.6 s | 61.9 s (**−29%**) |
| 2000 files, `--jobs=8` | 81.8 s | 61.7 s (**−25%**) |
| external forks per 2000 files | ~12 000 | ~8 000 |

The five changes:

1. **One ffprobe per video** — new `Get_Media_Info` fetches width, height and
   duration in a single call (was two separate ffprobe launches per video).
2. **Fork-free thread pool** — `Run_Threads` tracks running jobs with a bash
   counter instead of `jobs -rp | wc -l` (which forked twice per file submitted).
3. **No `du` per file** — `Get_File_Size_Human` now computes the human-readable
   size from one `stat` + bash arithmetic (was `du -h | cut`, two forks per file);
   the size subfolder reads the byte count once for both the class and the size.
4. **Side-effect-free preview** — `mkdir -p` of the target tree now happens only
   in Copy/Move modes; a dry run creates nothing.
5. **Cached date segments** — birth/mtime come from ONE cached `stat` call per
   file (`Sort_Stat_Cache`), and each `date` formatting fork is cached per
   file+format (`Sort_Date_Cache`), so `--dirs=year+month --subdirs=day` style
   specs no longer re-probe the same file.

The user interface is still built in **20 languages**, no external translation
files needed:

```
en  zh  hi  es  fr  ar  bn  pt  ru  ur
id  de  ja  tr  ko  vi  it  pl  nl  fa
```

- Default language: `en` (English) — zero overhead, strings pass through untouched
- `--lang=XX` selects the UI language for this run; `--lang` (bare) prints the
  language list with native names
- An unsupported code is rejected with the list of valid languages
- Example command lines, keyword lists and hash names stay literal by design
- The FreePascal port (`Sort-V17.2.pas`) carries the same 20-language UI via
  its own `Tr`/`Tf` translation layer; the fork optimizations are inherent to
  the native implementation (real threads, native stat/time, preview exits
  before any directory creation)

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
./Sort-V17.2.sh

# 2) test fase — try it on a scratch copy first (non-destructive)
mkdir -p /tmp/sort-test && cp ~/Pictures/a.jpg ~/Documents/b.pdf /tmp/sort-test/
cd /tmp/sort-test
/path/to/Sort-V17.2.sh --mode=copy --recursive --jobs=2 --colored .

# 3) move variant — check the built-in menu for all mode words
/path/to/Sort-V17.2.sh --mode=move --recursive ~/Pictures/2Sort
```

## About the author

The Sort scripts are written by **HEjder** — Ali ISIN, writing under the nickname
**Ejder / HEjder**. Every script in this repository is a HEjder edition: syntax
errors corrected, formatting unified, every function commented, and each one ends
with `Thanks for using HEjder scripts!`.

## Usage

```bash
chmod +x Sort-V17.2.sh
./Sort-V17.2.sh --lang          # language list
./Sort-V17.2.sh --lang=de --help
./Sort-V17.2.sh --lang=tr --mode=move --dirs=year+month ~/Pics
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V17.2.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V17.2.pas
./Sort-V17.2
```

NB/This code is not tested yet! — the port could not be compiled inside the
build sandbox (no FPC compiler available); please verify locally.

---

## Appendix — the same text in the top 5 alphabets

Caution, explanation, example and author — the same English words, rendered
phonetically in the top 5 symbol systems, one after the other (the example
command stays runnable in all of them).

**English (Latin alphabet)**

Sort 17.2 — sort, rename and organize your files. Caution: be careful with this script, understand it before you use it, especially the remove, trash and shred modes. Example: ./Sort-V17.2.sh — Author: HEjder

**中文符号 (Han symbols)**

索特 17.2 — 索特、雷内姆 安徳 奥根奈兹 尤尔 法伊尔斯。凯申：比 凯尔富 威兹 迪斯 斯克里普特，安德斯坦德 伊特 比福 尤 尤兹 伊特，埃斯佩谢利 泽 雷穆夫、特拉什 安徳 什雷德 穆兹。埃克桑普尔：./Sort-V17.2.sh — 奥瑟：海杰德

**देवनागरी (Devanagari)**

सॉर्ट 17.2 — सॉर्ट, रिनेम ऍण्ड ऑर्गनाइझ युअर फाइल्स. कॉशन: बी केअरफुल विथ दिस स्क्रिप्ट, अंडरस्टैंड इट बिफोर यू यूज़ इट, एस्पेशियली द रिमूव, ट्रॅश ऍण्ड श्रेड मोड्स. इग्ज़ाम्पल: ./Sort-V17.2.sh — ऑथर: हेजडेर

**Кириллица (Cyrillic)**

Сорт 17.2 — сорт, ринейм энд органайз ёр файлс. Кэйшн: би кэрефул уиз зис скрипт, андэстенд ит бифор ю юз ит, эспешали зе римув, трэш энд шред моудс. Экзампл: ./Sort-V17.2.sh — Атор: Хейдер

**العربية (Arabic)**

سورت 17.2 — سورت، رينيم أند أورغنايز يور فايلز. كيوشن: بي كيرفول ويذ ذيس سكريبت، أندرستند إت بيفور يو يوز إت، إسبشالي ذا ريموف، تراش أند شرد موودز. إكزامبل: ./Sort-V17.2.sh — أوثور: هيدجر


---

## Python edition - Sort-VV17.2.py

This directory also carries **Sort-VV17.2.py**, a / standalone, standard-library-only
Python edition of the same version. It makes **no external calls at all**: no
`file`, `ffprobe`, `identify`, `exiftool`... - pure Python 3 (Debian `python3`).

* Same directory logic era as the Bash edition above (modes, options and
  template keywords are gated to what this era's Bash script supports; the
  allowed set is printed by `Sort-VV17.2.py -h`).
* Where the Bash edition depended on external tools, the Python edition
  implements the equivalent natively (checksums, MIME sniffing, image
  dimensions) - or **strips that option** when there is no native equivalent:
  --decompress: archive decompress (--decompress) - stripped; --delete: delete mode - use --mode=remove; --exif: EXIF rename/strip levels (--exif) - stripped; --needed: dependency listing - stripped; --noconfirm: interactive confirm - stripped; --non-interactive: interactive confirm - stripped; --stats: stats mode (--stats) - stripped; --strip: metadata stripping (--strip) - stripped; --title: metadata title rename (--title) - stripped; --verbose: verbose flag - use default output; --version: --version
* Usage: `python3 Sort-VV17.2.py --mode=dummy FILES...`
* Self check: `python3 Sort-VV17.2.py --self-test`
* Not portable to Python in this edition: nothing - the file is fully
  self-contained (the engine is embedded; no other files are imported).


### Update - embedded native metadata keywords

This Python edition now embeds the **native EXIF (JPEG APP1/TIFF) and ID3
(MP3 v1/v2) parsers** directly (stdlib-only, still zero external calls and
zero imports): the metadata-template keywords of this era work fully
standalone - exif-* plus the --rename=title audio/metadata keyword. Example:
`python3 Sort-V17.2.py --mode=copy --subdirs=exif-date photo.jpg`
