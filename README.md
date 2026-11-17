## Hey,

# !! BE CAREFULL WITH THIS SCRIPT !!
I strongly advise you to understand the scripts content before you use it!

"Offen, when recovering files with 'PhotoRec' or something similar,
You end-up with a bunch of 'folders and files' mixed up!

That's when I prefer this script to sort things out,
'With ease'.."

NB/If you want more options, please give a sign!

# Exp1)

cd Pictures/Wallpapers ;
~/BASH/Sort.sh --Move --Recursive --Replace --Rename=random --SubDirs=size *

"This moves all files in Wallpapers - renaming to random-numbers - in to WorkingDirectory/WIDTHxHEIGHT - recursively!"

# Exp2)

	cd Pictures/Wallpapers ;
	~/BASH/Sort.sh --Move --Recursive --Replace --Rename=sha256sum --Dirs=mime-sub --SubDirs=format+size .

"This moves all files in WorkingDirectory - renaming to SHA256SUM of the files as filename - in to WorkingDirectory/MIME-TYPE/MIME-SUBTYPE/FORMAT/FORMAT2/WIDTHxHEIGHT - recursively!"

# Exp3)

	cd Pictures/Sorted ;
	~/BASH/Sort.sh --Copy --Recursive --Replace --Dirs=mime-sub --SubDirs=format+size ~/Pictures/2Sort

"This copies all files from the directory $HOME/Pictures/2Sort - keeping filenames - in to WorkingDirectory/MIME-SUBTYPE/FORMAT/FORMAT2/WIDTHxHEIGTH - recursively!"

# Exp4)

	cd Pictures/2Sort ;
	~/BASH/Sort.sh --Remove --Recursive --Dirs=mime-sub --SubDirs=format+size ~/Pictures/Sorted

"This removes all files in WorkingDirectory - all files with simalar names - from the $HOME/Pictures/Sorted/FORMAT/FORMAT2/WIDTHxHEIGHT - recursively!"

!! You can use 'size' option with other files - other than pictures - where FORMAT and SIZE changes (exp '../MegaByte/5/' or '../5GiB/') !!

---

# The version archive

This repository now keeps the **complete history of the Sort script** — 92 versions,
reconstructed from content evolution and numbered `V1.0` → `V15.1` (the version labels
found inside the old files were inconsistent, so they were discarded and re-derived;
see [Sort-Versions.md](Sort-Versions.md) for the full map, sources and reasoning).

## Layout

```
Sort.sh                 <- MAIN script (V17.0, self-contained, all lineage features)
Sort-Versions.md        <- the full version map: every version, its source, its notes
FUNCTIONS/              <- legacy helper library sourced by Sort.sh (V15.1)
  get_file.sh           <- get_file_*, built on functions/file + functions/hash
  get_mime.sh           <- get_mime*, built on functions/mime
  get_image_exif.sh     <- get_image_*, built on functions/imagemagick
  get_video_exif.sh     <- get_video_*, built on functions/ffmpeg
versions/
  V1.0/
    Sort-V1.0.sh        <- the script itself (HEjder edition)
    README.md           <- custom readme for this version
  V1.1/
    Sort-V1.1.sh
    README.md
  ...
  V15.1/
    Sort-V15.1.sh
    README.md
functions/              <- isolated function library (see functions/README.md)
  system/system.sh      <- Exit, Break
  ui/ui.sh              <- Draw_Line
  file/file.sh          <- Get_MIME, Get_File_*, Get_Date_Part
  hash/hash.sh          <- Get_MD5Sum, Get_SHA_Keys, Get_SHA256Sum
  imagemagick/imagemagick.sh <- Get_Image_WxH, Get_Image_Meta, Get_WxH_Format
  ffmpeg/ffmpeg.sh      <- Get_Media_WxH, Get_Audio_Info, Get_Video_Title
  docs/docs.sh          <- Get_Doc_Title
  core/core.sh          <- Resolve_Path_Segment, Parse_Arguments, Validate_Options,
                           Perform_Action, Sort, Show_Help
```

All 28 functions of the Sort mainline are also available as isolated, per-resource
modules under `functions/` — each with its own ASCII header (script name, version,
description, author: HEjder) and a logical name: `system`, `ui`, `file`, `hash`,
`imagemagick`, `ffmpeg`, `docs`, `core`.

Every version folder contains the script and its own README with: era, source,
size, position in the lineage, notes, and any fixes that were applied.

## The main script

The root `Sort.sh` is **V17.0 — the self-contained edition**: a comparison
with all 92 lineage versions was made and **every functionality from
V1.0–V15.1 is merged in**, with all needed functions embedded (no external
`FUNCTIONS/` or `functions/` sourcing — the script runs standalone).

Merged lineage features:

- **Modes** (V9.x/V12.x/V13.1): `--copy`, `--move`, `--remove`/`--delete`,
  `--trash`, `--shred`, `--mode=…` — destructive modes act on the
  calculated TARGET path and refuse source = target
- **Dynamic values** (V13.1 engine): `--dirs=` / `--subdirs=` /
  `--rename=` / `--extension=` accept keywords — `year`, `month`, `day`,
  `year+month`, `created`/`modified`/`accessed`, `mime`, `mime-main`,
  `mime-sub`, `extension`, the whole checksum family (`md5`…`sha512`,
  `b2`, `crc32`), `random`, `randomN`, `size`, `format` (resolution tiers
  TINY…HUGE × SQUARE/WIDE/HIGH), `duration`, `camera`, `exifdate`,
  `title` — unknown words become literal names
- **Filtering** (V7.x/V8.x/V13.x): `--type=VALUE` (MIME substring),
  `--recursive`, `--hidden`, `--links`
- **Destination** (V8.x): `--target=DIR`, `--dirs=`, `--subdirs=`
- **Metadata** (V10.x/V13.1 + v16.1): `--title` (PDF /Title, EXIF date,
  audio/video tags), `--exif` (`<Camera>/<date>` levels), `--strip`
- **Safety/output** (V10.2/V12.x): `--log=FILE`, `--undo[=FILE]` (writes a
  runnable undo script), `--pause=SEC`, `--replace` vs `~(N)` collision
  names, `--quiet`, `--colored`, `--stats`
- **Threading** (V12.x + v16.0): file array built up front, bounded
  background-job pool (`--jobs=N`, default nproc)
- **Init-system**: missing tools (`identify`, `ffprobe`, `exiftool`,
  `trash-put`) are proposed for install on first use

It collects every file to treat into an array up front, sorts each into
the dynamic tree, and processes the array through the job pool. Verbose by
default, colored output with `--colored`, dry-run preview by default
(`--copy` / `--move` to act), full `--help` and `--usage` sections.

The previous main script, **V15.1 — the modular library edition**, sources
its helper functions from a `FUNCTIONS/*.sh` directory (next to it in the
repository root) — the original library was never uploaded, so it was
rebuilt as adapters over the modern `functions/` toolkit. If you want a
single self-contained file instead, use
**[versions/V13.1](versions/V13.1/Sort-V13.1.sh)** — the most developed
standalone edition — or the classic **[versions/V11.0](versions/V11.0/Sort-V11.0.sh)**
(the version that was previously published here as `Sort.sh`).

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

## HEjder edition

All 92 scripts are HEjder editions: every syntax error fixed (all pass `bash -n`),
formatting unified, author credited as **HEjder**, every function commented, and each
script ends with:

	Thanks for using HEjder scripts!

---

Under developpement!
