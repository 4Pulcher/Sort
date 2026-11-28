# Sort V17.4 - Python edition

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

| | |
|---|---|
| **Version** | V17.4 |
| **Language** | Python (Python edition) |
| **Era** | V17.x — self-contained rewrite |
| **Source** | V17.2 + audio tags (ID3v1 / ID3v2, new `id3-*` keywords) |
| **Download** | https://github.com/4Pulcher/Sort/archive/refs/heads/main.zip |

## Caution - test phase

**Be careful with this script.** The Sort code is in a **test phase**: every
version passes syntax checks and the available self-tests, but it is not
field-tested on real data. Always run it on a scratch copy first, and read the
dry-run preview before confirming any action.

## Build / run

No build needed: `python3 Sort-VV17.4.py` (`--self-test` verifies the engine)


## About the author

The Sort scripts are written by **Ali ISIN (HEjder / Ejder)**. Every script in this repository is a
HEjder edition: syntax errors corrected, formatting unified, every function
commented, and the Bash editions end with `Thanks for using HEjder scripts!`.

## Thanks

Thanks to everyone who followed the HEjder scripts lineage from the earliest
Ejder-scripts organizer to today's multi-language, multi-edition family -
and to Garry's magic-number collection, which feeds the V22 signature engine.
