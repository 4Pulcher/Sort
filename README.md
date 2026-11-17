## Hey,

# !! BE CAREFULL WITH THIS SCRIPT !!
I strongly advise you to understand the scripts content before you use it!

"Offen, when recovering files with 'PhotoRec' or something similar,
You end-up with a bunch of 'folders and files' mixed up!

That's when I prefer this script to sort things out,
'With ease'.."

NB/If you want more options, please give a sign!

---

# Sort.sh — V17.0, the self-contained edition

One single file, no external libraries: a comparison with **all 92 lineage
versions** was made and **every functionality from V1.0–V15.1 is merged in**,
with all needed functions embedded. It collects every file to treat into an
array up front, sorts each into a dynamic directory tree, and processes the
array through a bounded pool of background jobs (threading).

- **Dry-run preview by default** — nothing moves until you say `--copy` or `--move`
- **Verbose by default**, colored output with `--colored`
- **Modes**: `--copy`, `--move`, `--remove`/`--delete`, `--trash`, `--shred` (destructive modes act on the calculated TARGET path and refuse source = target)
- **Dynamic values**: `--dirs=`, `--subdirs=`, `--rename=`, `--extension=` accept keywords — dates (`year`, `year+month`, `modified`, ...), `mime`, `mime-main`, `mime-sub`, `extension`, `mime-ext` (best matching extension for the MIME type), checksums (`md5` … `sha512`, `b2`, `crc32`), `random`, `randomN`, `size`, `format` (tiers `TINY…HUGE` × `SQUARE/WIDE/HIGH`), `duration`, `camera`, `exifdate`, `title` — unknown words become literal names
- **Default naming**: without `--rename=`/`--title`, files keep their plain name when they come from the working directory itself; files found in other folders get their folder prefixed (`sub_b.txt`) so same-named files never collide
- **Filtering**: `--type=image|video|...` (MIME substring), `--recursive`, `--hidden`, `--links`
- **Metadata**: `--title` (PDF `/Title`, EXIF date, audio/video tags), `--exif` (`<Camera>/<date>` levels), `--strip` (remove EXIF/GPS from targets)
- **Safety net**: `--log=FILE`, `--undo[=FILE]` (writes a runnable undo script), `--pause=SEC`, `--replace` vs automatic `~(N)` collision names
- **Threading**: `--jobs=N` (default: nproc)
- **Archives**: `--decompress` (extract to a temp dir, sort the contents, then delete the archive — `--trash`/`--shred` apply that fate to it), `--rename=compressed` (name = main dir / single file inside the archive); compound extensions like `.tar.gz`/`.TAR.GZ` count as one extension
- **Init-system**: missing tools (`identify`, `ffprobe`, `exiftool`, `trash-put`, `7z`, `unrar`, ...) are proposed for install on first use

Full reference: `./Sort.sh --help` — short reminder: `./Sort.sh --usage`.

---

# 8 examples

## Exp1) The classic PhotoRec rescue — random names, size folders

```bash
cd Pictures/Wallpapers ;
~/BASH/Sort.sh --copy --recursive --replace --rename=random --subdirs=size *
```

> Copies all files in Wallpapers — renaming to random numbers — into
> `WorkingDirectory/<MIME>/<WIDTHxHEIGHT>` — recursively! Preview first by
> dropping `--copy`.

## Exp2) SHA256 names, full media tree

```bash
cd Pictures/Wallpapers ;
~/BASH/Sort.sh --move --recursive --replace --rename=sha256sum --extension=none --dirs=mime --subdirs=format+size .
```

> Moves all files in the working directory — renaming to the SHA256 of the
> file — into `WorkingDirectory/<MIME-TYPE>/<TIER>/<ORIENTATION>/<WIDTHxHEIGHT>`
> — recursively! Identical files end up with identical names, so duplicates
> collapse naturally.

## Exp3) Collect from a source directory into the current tree

```bash
cd Pictures/Sorted ;
~/BASH/Sort.sh --copy --recursive --replace --dirs=mime-sub --subdirs=format+size ~/Pictures/2Sort
```

> Copies all files from `$HOME/Pictures/2Sort` into
> `WorkingDirectory/<MIME-SUBTYPE>/<FORMAT>/<WIDTHxHEIGHT>` — recursively!
> Filenames are kept (folder-prefixed for files from sub-folders, e.g.
> `sub_b.txt`, so same-named files never overwrite each other).

## Exp4) Dates first — archive by year/month

```bash
~/BASH/Sort.sh --move --recursive --dirs=year+month --subdirs=mime-main --target=~/Archive ~/Pictures/2Sort
```

> Moves everything into `$HOME/Archive/<YYYY>/<MM>/<IMAGE|VIDEO|...>/` —
> organized by the files' own timestamps. Add `--rename=sha256sum` for a
> duplicate-proof archive.

## Exp5) EXIF — camera and shooting-date levels

```bash
~/BASH/Sort.sh --copy --recursive --exif --type=image --target=~/Pictures/ByCamera ~/DCIM
```

> Copies only images, into
> `ByCamera/<MIME>/<Canon_EOS_5D>/<2024-03-14>/<Landscape>/<1920x1080>/` —
> camera and capture date read from the EXIF data (exiftool). The job pool
> (`--jobs=N`) handles large collections.

## Exp6) Metadata titles — rename documents and media by what they contain

```bash
~/BASH/Sort.sh --move --title --type=application --target=~/Docs ~/Downloads
```

> Moves PDFs and office documents into `~/Docs/<MIME>/...`, renaming each by
> its internal `/Title` (`Report_2024` style). For audio/video the tags
> (`Artist_Album_Title`) are used instead.

## Exp7) The safety net — log file plus undo script

```bash
~/BASH/Sort.sh --move --recursive --log=sort.log --undo ~/Downloads
```

> Moves everything, appends one timestamped line per action to `sort.log`,
> and writes `sort_undo_<time>.sh` — run that script to reverse the moves.

## Exp8) Cleanup — trash or shred at the calculated target

```bash
~/BASH/Sort.sh --trash --type=image --dirs=mime --subdirs=size ~/Sorted
~/BASH/Sort.sh --shred --type=image --dirs=mime --subdirs=size ~/Sorted
```

> Destructive modes act on the file at the **calculated TARGET path** —
> review the preview first! Source = target is refused; `--trash` needs
> `trash-put`, `--shred` overwrites with `shred -u -n 1`.

---

# The version archive

This repository keeps the **complete history of the Sort script** — 95 versions:
92 reconstructed from content evolution and numbered `V1.0` → `V15.1` (the version labels
found inside the old files were inconsistent, so they were discarded and re-derived),
plus the three rewrite editions `V16.0`, `V16.1` and `V17.0`. The last version is always
the main one: root `Sort.sh` = `V17.0`
(see [Sort-Versions.md](Sort-Versions.md) for the full map, sources and reasoning).

## Layout

```
Sort.sh                 <- MAIN script (V17.0, self-contained, all lineage features)
Sort.pas                <- MAIN FreePascal translation (V17.0 port)
Sort-Versions.md        <- the full version map: every version, its source, its notes
FUNCTIONS/              <- legacy helper library sourced by Sort.sh (V15.1)
  get_file.sh           <- get_file_*, built on functions/file + functions/hash
  get_mime.sh           <- get_mime*, built on functions/mime
  get_image_exif.sh     <- get_image_*, built on functions/imagemagick
  get_video_exif.sh     <- get_video_*, built on functions/ffmpeg
versions/
  V1.0/
    Sort-V1.0.sh        <- the script itself (HEjder edition)
    Sort-V1.0.pas       <- FreePascal 3.2.2 translation of this version
    README.md           <- custom readme for this version
  ...
  V15.1/
    Sort-V15.1.sh
    Sort-V15.1.pas
    README.md
  ...
  V17.0/
    Sort-V17.0.sh        <- identical to the root Sort.sh
    Sort-V17.0.pas       <- identical to the root Sort.pas
    README.md
functions/              <- isolated function library (see functions/README.md)
  system/  ui/  file/  hash/  mime/  imagemagick/  ffmpeg/  exif/
  compression/  docs/    core/  colors/  deps/
```

- `functions/` — the modern, isolated per-resource toolkit (190 functions:
  file, hash, mime, imagemagick, ffmpeg, exif, compression, colors, deps,
  system, ui, docs, core), each module with its own ASCII header and README
- `FUNCTIONS/` — the legacy lowercase adapter layer that V15.1 sources
- Every version folder contains the script and its own README with: era,
  source, size, position in the lineage, notes, and any fixes applied

## The previous main scripts

- **V15.1 — the modular library edition** sources its helpers from
  `FUNCTIONS/*.sh` (rebuilt as adapters over `functions/`, since the
  original library was never uploaded)
- **[V13.1](versions/V13.1/Sort-V13.1.sh)** — the most developed
  *standalone* edition of the old lineage
- **[V11.0](versions/V11.0/Sort-V11.0.sh)** — the classic edition that was
  previously published here as `Sort.sh`

## The eras

| Era | Versions | What |
|---|---|---|
| V1.x | 1.0–1.5 | Ejder-scripts organizer (earliest) |
| V2.x | 2.0–2.13 | Prototype micro-scripts |
| V3.x | 3.0–3.6 | Launchers / wrappers |
| V4.x | 4.0–4.5 | CamelCase era |
| V5.x | 5.0–5.8 | Media-Intelligent mainline |
| V6.x | 6.0–6.19 | Optimized lineage |
| V7.x | 7.0–7.1 | Readonly-sections pair |
| V8.x | 8.0–8.7 | Source/target era |
| V9.x | 9.0–9.5 | Safe copy/move/remove modes |
| V10.x | 10.0–10.2 | Annotated era |
| V11.x | 11.0 | GitHub mainline (the old root `Sort.sh`) |
| V12.x | 12.0–12.3 | Threaded generations |
| V13.x | 13.0–13.1 | Commented edition |
| V14.x | 14.0–14.1 | Safe Transport Engine |
| V15.x | 15.0–15.1 | Modular library era |
| V16.x | 16.0–16.1 | Rewrite on the `functions/` toolkit (threaded) |
| V17.x | 17.0 | Self-contained all-features edition (the current main) |

## FreePascal translations

**Every version — all 95 plus the main script — is also available as a
FreePascal program**: root `Sort.pas` (the V17.0 port) and
`versions/V#.#/Sort-V#.#.pas` for each version.

- Written for **FreePascal 3.2.2**, `{$MODE OBJFPC}{$H+}` — stated in every
  file header, with the compile hint `fpc -Mobjfpc -Sh <file>.pas`
- **Native FPC libraries wherever possible**: `SysUtils`, `Classes`, `Math`,
  `SyncObjs` (thread pool with `TCriticalSection`), `MD5` and `SHA1`
  (packages/hash — native hashing), `Zipper` (FCL zip read/extract),
  `BaseUnix` (stat / symlink / chmod), `Process` (`TProcess` for the same
  external tools the shell called: file, exiftool, ffprobe, identify,
  trash-put, shred, tar, 7z, unrar, ...)
- **SHA256/SHA512 have no native FPC unit** (packages/hash only ships md5 and
  sha1), so those fall back to the external `sha256sum`/`sha512sum` tools —
  exactly what the shell versions did
- Each port keeps its version's own option set and era behavior (V1.x
  positional words, V2.x extension sorter, V3.x+ option parser, ...)
- NB/These translations were written conservatively for FPC 3.2.2 but could
  not be compiled inside the build sandbox (no FPC compiler available) —
  verify locally with `fpc -Mobjfpc -Sh Sort.pas`

## HEjder edition

All 92 lineage scripts are HEjder editions: every syntax error fixed (all pass `bash -n`),
formatting unified, author credited as **HEjder**, every function commented, and each
script ends with:

	Thanks for using HEjder scripts!

---

Under developpement!
