# functions — HEjder function library

Isolated, per-resource modules extracted from the Sort mainline
(source: version V13.1, the most developed standalone edition),
expanded into complete standalone toolkits.

Load them in your own script with:

```bash
source functions/system/system.sh
source functions/file/file.sh
# ...
```

Note: the `system`, `ui` and `core` modules use globals defined by the main
script (option values); source the color/ui setup first or define them
yourself — or use the standalone [colors](colors/) module instead. The
`file`, `hash`, `imagemagick`, `ffmpeg`, `exif`, `deps`, `colors`, `mime`
and `compression` modules are fully standalone — no main-script globals
required.

## Modules

| Module | Resource | Functions |
|---|---|---|
| [system](system/) | System process control | `Exit`, `Break` |
| [ui](ui/) | Terminal display | `Draw_Line` |
| [file](file/) | Complete file toolkit — coreutils / file(1) | 38 functions: MIME, name/extension splitting, sizes, timestamps, permissions, ownership, predicates |
| [hash](hash/) | Complete checksum toolkit — md5 / SHA family / crc32 / blake2 | 22 functions: per-algorithm getters, dispatcher, string hashing, verification, containment, directory diff/minus, duplicate finding |
| [imagemagick](imagemagick/) | Complete image toolkit — ImageMagick identify / magick | 20 functions: dimensions, format, colors, depth, quality, DPI, orientation, camera, GPS, actions |
| [ffmpeg](ffmpeg/) | Complete media toolkit — ffmpeg / ffprobe | 24 functions: codecs, container, duration, bitrate, FPS, channels, tags, actions |
| [exif](exif/) | Complete EXIF toolkit — exiftool / ImageMagick fallback | 23 functions: generic tag access, dumps, camera, lens, exposure, GPS, strip/set/copy actions |
| [deps](deps/) | Init-system for external tools — installer / privilege detection | 8 functions: detection, package mapping, install, ensure, init |
| [colors](colors/) | Complete color toolkit — ANSI colors / print helpers | 13 functions: `C_*` color variables, Print_Message/Info/Ok/Error/Warning/Log/Debug, headers, separators |
| [mime](mime/) | Complete MIME toolkit — file(1) / magic bytes / extension maps | 20 functions: type/main/sub/description/charset, magic bytes, magic detection, database-sourced MIME↔extension maps (911 extensions / 687 types), pattern match, type predicates |
| [compression](compression/) | Complete archive toolkit — tar / gz / bz2 / xz / zst / zip / 7z / rar | 12 functions: magic-byte type detection, integrity test, listing, extraction, main-name lookup, creation, single-file compression |
| [docs](docs/) | Documents (pdftotext / exiftool) | `Get_Doc_Title` |
| [core](core/) | Organizer core logic | `Resolve_Path_Segment`, `Parse_Arguments`, `Validate_Options`, `Perform_Action`, `Sort`, `Show_Help` |

Total: 190 functions in 13 modules.
