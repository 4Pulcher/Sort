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
script (ANSI color variables, option values); source the color/ui setup first
or define them yourself. The `file`, `hash`, `imagemagick` and `ffmpeg`
modules are fully standalone — no globals required.

## Modules

| Module | Resource | Functions |
|---|---|---|
| [system](system/) | System process control | `Exit`, `Break` |
| [ui](ui/) | Terminal display | `Draw_Line` |
| [file](file/) | Complete file toolkit — coreutils / file(1) | 38 functions: MIME, name/extension splitting, sizes, timestamps, permissions, ownership, predicates |
| [hash](hash/) | Complete checksum toolkit — md5 / SHA family / crc32 / blake2 | 15 functions: per-algorithm getters, dispatcher, string hashing, verification, duplicate finding |
| [imagemagick](imagemagick/) | Complete image toolkit — ImageMagick identify / magick | 20 functions: dimensions, format, colors, depth, quality, DPI, orientation, camera, GPS, actions |
| [ffmpeg](ffmpeg/) | Complete media toolkit — ffmpeg / ffprobe | 24 functions: codecs, container, duration, bitrate, FPS, channels, tags, actions |
| [docs](docs/) | Documents (pdftotext / exiftool) | `Get_Doc_Title` |
| [core](core/) | Organizer core logic | `Resolve_Path_Segment`, `Parse_Arguments`, `Validate_Options`, `Perform_Action`, `Sort`, `Show_Help` |

Total: 107 functions in 8 modules.
