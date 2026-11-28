# VERSION.md - Sort V17.4 (FreePascal)

## About

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
./Sort-V17.4.sh --mode=move --dirs=id3 --rename=id3-track --extension=lower ~/Music
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
- The FreePascal port (`Sort-V17.4.pas`) carries the same 20-language UI via
  its own `Tr`/`Tf` translation layer; the fork optimizations are inherent to
  the native implementation (real threads, native stat/time, preview exits
  before any directory creation)

| Version | Language | Era | Source |
|---|---|---|---|
| V17.4 | FreePascal | V17.x — self-contained rewrite | V17.2 + audio tags (ID3v1 / ID3v2, new `id3-*` keywords) |

## Changes

- Fully standalone: copy this single file anywhere and it runs.
- Destructive modes act on the file at the **calculated TARGET path** and
- The root [Sort.sh](../../Sort.sh) is kept identical to this version.

## Thanks

Written by **Ali ISIN (HEjder / Ejder)**. Thanks for using HEjder scripts!
