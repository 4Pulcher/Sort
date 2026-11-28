# Sort.py - the Python line (stdlib only)

Pure-Python (standard library only) port of the complete Bash `Sort.sh`
lineage. No external commands are invoked anywhere: no `file`, no
ImageMagick, no FFmpeg, no ExifTool. Everything runs with Debian's `python3`
package (main repo) and nothing else.

## Layout

    python/
      Sort.py                    main engine (feature union of the lineage)
      functions/                 native function library (see below)
        __main__.py              python3 -m functions  -> full self-test
        editions.py              era model + V-gating for the 13 editions
      versions/
        Metadata-driven/  Sort-V1.py .. Sort-V6.py
        Media-Intelligent/ Sort-V1.py .. Sort-V7.py
      README.md                  this file

## Main

`Sort.py` is the full engine: magic-byte MIME sniffing, native
PNG/GIF/BMP/JPEG/WEBP dimensions, hashlib checksum keywords, the template
language (lower:/upper:/raw: prefixes, a|b|c fallbacks), modes
dummy/copy/move/remove/trash/shred, --jobs, --log + --undo, i18n, self-test.

    Sort.py --self-test
    Sort.py --mode=dummy --dirs=mime-main --type=image Downloads/*

## Functions library (Python equivalents of the shell `functions/` modules)

| Shell module   | Python module      | Replacement |
|----------------|--------------------|-------------|
| colors.sh      | colors.py          | ANSI styles + icon table |
| ui.sh          | ui.py              | UI class + translations (engine) |
| core.sh        | core.py            | engine re-exports |
| mime.sh        | mime.py            | native magic-byte sniffer |
| imagemagick.sh | image.py           | native image dimension parser |
| hash.sh        | hash.py            | hashlib wrappers |
| file.sh        | file.py            | FileFacts record + timestamp getters |
| exif.sh        | exif.py            | native JPEG EXIF (APP1/TIFF IFD) parser |
| tags.sh        | tags.py            | native ID3v1 + ID3v2 MP3 tag parser |
| compression.sh | compression.py     | zip/tar/gz/bz2/xz/7z/rar inspection |
| ffmpeg.sh      | (engine dims)      | no deep video metadata; container sniffs only |
| system.sh      | system.py          | freedesktop trash, shred, undo log |
| deps.sh        | deps.py            | interpreter + REPLACED_COMMANDS map |
| docs.sh        | docs.py            | manpage + feature map |
| testing.sh     | testing.py / __main__.py | self-test suite |

## Versions (13 eras)

Each wrapper calls `functions.editions.run(argv, line, era)`, which restricts
the engine to the keywords, modes, options and defaults of that historical
Bash edition (exit code 64 on out-of-era usage):

* `versions/Metadata-driven/Sort-V1..V6.py` - the metadata-driven line:
  V1 base modes + md5/sha256, V2 full hashes, V3 templates, V4 context,
  V5 ext-lower/bytes, V6 modifiers + fallbacks + --jobs.
* `versions/Media-Intelligent/Sort-V1..V7.py` - the media-intelligent line:
  V1 base|hashes|pixel, V2 empty-dir cleanup, V3 icons, V4 --jobs,
  V5 stable, V6 --pause/--log, V7 tags (EXIF/ID3 keywords).

Run one:

    python3 python/versions/Media-Intelligent/Sort-V7.py \
        --dirs=exif-make --mode=copy photo.jpg

## Self-test

    cd python && python3 -m functions      # engine 23 checks + EXIF/ID3/era checks
    python3 Sort.py --self-test
