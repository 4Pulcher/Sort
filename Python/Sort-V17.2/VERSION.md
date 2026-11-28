# VERSION.md - Sort V17.2 (Python)

## About

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

| Version | Language | Era | Source |
|---|---|---|---|
| V17.2 | Python | V17.x — self-contained rewrite | V17.1 + performance edition (fewer forks per file) |

## Changes

- Fully standalone: copy this single file anywhere and it runs.
- Destructive modes act on the file at the **calculated TARGET path** and
- The root [Sort.sh](../../Sort.sh) is kept identical to this version.

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
