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
or define them yourself. The `file`, `hash`, `imagemagick`, `ffmpeg` and
`exif` modules are fully standalone — no globals required.

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
| [docs](docs/) | Documents (pdftotext / exiftool) | `Get_Doc_Title` |
| [core](core/) | Organizer core logic | `Resolve_Path_Segment`, `Parse_Arguments`, `Validate_Options`, `Perform_Action`, `Sort`, `Show_Help` |

Total: 137 functions in 9 modules.
