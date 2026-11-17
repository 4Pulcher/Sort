# Sort — Version 17.3

> The self-contained edition, now reading the tags inside your music — ID3v1 and ID3v2, pure bash.

| | |
|---|---|
| **Version** | 17.3 |
| **Era** | V17.x — self-contained rewrite |
| **Source** | V17.2 + audio tags (ID3v1 / ID3v2, new `id3-*` keywords) |
| **Size** | 9197 lines (.sh) |
| **Role** | Current main script — identical to the root `Sort.sh` |
| **Preceded by** | V17.1 |
| **Followed by** | — (last version) |

## About this version

Everything from V17.2 (all lineage features merged, 12 modules inlined,
threading, dynamic values, archives, EXIF, init-system, 20-language UI, and the
full V17.2 performance edition: one ffprobe per video, fork-free thread pool,
du-free sizes, side-effect-free preview, cached date segments) plus an
**audio-tag edition** — a new TAGS module reads ID3v1 and ID3v2 tags from audio
files in **pure bash** (no external tag tool needed):

1. **ID3v1** — the last 128 bytes of the file: title, artist, album, year,
   comment, track and the 126-entry genre table (80 standard + Winamp
   extensions); track is only reported when the v1.1 zero-byte marker is set.
2. **ID3v2.2 / v2.3 / v2.4** — full frame walk: 3-char IDs and byte sizes for
   v2.2, 4-char IDs for v2.3, synchsafe sizes for v2.4; text encodings
   ISO-8859-1, UTF-16 (BOM), UTF-16BE and UTF-8 are decoded via `iconv`.
3. **Friendly getters with fallback** — `Get_Audio_Title/Artist/Album/Year/
   Genre/Track` try the ID3 frames first, then ID3v1, then fall back to the
   EXIF module (`exiftool`) for FLAC, Ogg, M4A and WMA.
4. **New `--rename` / `--subdirs` keywords** — `id3` / `audio` build the
   conventional `Artist/Year - Album` tree; `id3-title`, `id3-artist`,
   `id3-album`, `id3-year`, `id3-genre`, `id3-track` give single fields.
5. **Upgraded `--extension`** — new `lower` and `upper` force the extension
   case, `mime-main` yields the MIME main type (`audio/mpeg` → `audio`), and
   all dynamic keywords (`id3-genre`, `mime-sub`, …) now work there too.

Example:

```bash
./Sort-V17.3.sh --mode=move --dirs=id3 --rename=id3-track --extension=lower ~/Music
# -> Music/HEjder/1999 - Big Album/7.mp3
```

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
- The FreePascal port (`Sort-V17.3.pas`) carries the same 20-language UI via
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
./Sort-V17.3.sh

# 2) test fase — try it on a scratch copy first (non-destructive)
mkdir -p /tmp/sort-test && cp ~/Pictures/a.jpg ~/Documents/b.pdf /tmp/sort-test/
cd /tmp/sort-test
/path/to/Sort-V17.3.sh --mode=copy --recursive --jobs=2 --colored .

# 3) move variant — check the built-in menu for all mode words
/path/to/Sort-V17.3.sh --mode=move --recursive ~/Pictures/2Sort

# 4) audio tags — Artist/Year - Album tree, track number as name
./Sort-V17.3.sh --mode=move --dirs=id3 --rename=id3-track ~/Music
```

## About the author

The Sort scripts are written by **HEjder** — Ali ISIN, writing under the nickname
**Ejder / HEjder**. Every script in this repository is a HEjder edition: syntax
errors corrected, formatting unified, every function commented, and each one ends
with `Thanks for using HEjder scripts!`.

## Usage

```bash
chmod +x Sort-V17.3.sh
./Sort-V17.3.sh --lang          # language list
./Sort-V17.3.sh --lang=de --help
./Sort-V17.3.sh --lang=tr --mode=move --dirs=year+month ~/Pics
```

All scripts are HEjder editions: errors corrected, formatting unified,
author credited as **HEjder**, ending with `Thanks for using HEjder scripts!`.

## FreePascal translation

This version also ships as a FreePascal port: `Sort-V17.3.pas` (same directory).
Written for **FreePascal 3.2.2** (`{$MODE OBJFPC}{$H+}`) and stated in the file
header, using native FPC libraries wherever possible (SysUtils, Classes, and —
per version — Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process). FPC has no
native SHA256/SHA512 unit, so those fall back to the external `sha256sum` /
`sha512sum` tools, exactly like the shell version.

```bash
fpc -Mobjfpc -Sh Sort-V17.3.pas
./Sort-V17.3
```

NB/This code is not tested yet! — the port could not be compiled inside the
build sandbox (no FPC compiler available); please verify locally.

---

## Appendix — the same text in the top 5 alphabets

Caution, explanation, example and author — the same English words, rendered
phonetically in the top 5 symbol systems, one after the other (the example
command stays runnable in all of them).

**English (Latin alphabet)**

Sort 17.3 — sort, rename and organize your files. Caution: be careful with this script, understand it before you use it, especially the remove, trash and shred modes. Example: ./Sort-V17.3.sh — Author: HEjder

**中文符号 (Han symbols)**

索特 17.3 — 索特、雷内姆 安徳 奥根奈兹 尤尔 法伊尔斯。凯申：比 凯尔富 威兹 迪斯 斯克里普特，安德斯坦德 伊特 比福 尤 尤兹 伊特，埃斯佩谢利 泽 雷穆夫、特拉什 安徳 什雷德 穆兹。埃克桑普尔：./Sort-V17.3.sh — 奥瑟：海杰德

**देवनागरी (Devanagari)**

सॉर्ट 17.3 — सॉर्ट, रिनेम ऍण्ड ऑर्गनाइझ युअर फाइल्स. कॉशन: बी केअरफुल विथ दिस स्क्रिप्ट, अंडरस्टैंड इट बिफोर यू यूज़ इट, एस्पेशियली द रिमूव, ट्रॅश ऍण्ड श्रेड मोड्स. इग्ज़ाम्पल: ./Sort-V17.3.sh — ऑथर: हेजडेर

**Кириллица (Cyrillic)**

Сорт 17.3 — сорт, ринейм энд органайз ёр файлс. Кэйшн: би кэрефул уиз зис скрипт, андэстенд ит бифор ю юз ит, эспешали зе римув, трэш энд шред моудс. Экзампл: ./Sort-V17.3.sh — Атор: Хейдер

**العربية (Arabic)**

سورت 17.3 — سورت، رينيم أند أورغنايز يور فايلز. كيوشن: بي كيرفول ويذ ذيس سكريبت، أندرستند إت بيفور يو يوز إت، إسبشالي ذا ريموف، تراش أند شرد موودز. إكزامبل: ./Sort-V17.3.sh — أوثور: هيدجر
