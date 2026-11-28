# functions/ - the Python function library

The modular equivalent of the Bash lineage's `functions/` library (the
vibe-branch archaeology documented 212 shell functions in 14 modules and
matching FreePascal units). **Everything here is standard-library Python:
no `file`, no `ffprobe`, no `identify`, no `exiftool`, no coreutils
invocations.**

| Module | Shell module it replaces | Notes |
|---|---|---|
| `colors.py` | `functions/colors` | static ANSI + unicode icons (no `tput`) |
| `ui.py` | `functions/ui` | output + i18n table (V17.1 heritage) |
| `mime.py` | `functions/mime`, `file` | magic-byte sniffing, text heuristics |
| `image.py` | `functions/imagemagick` | native PNG/GIF/BMP/JPEG/WEBP dimensions |
| `hash.py` | `functions/hash` | hashlib for all `*sum` keywords |
| `file.py` | `functions/file` | FileFacts, timestamps, size tokens |
| `exif.py` | `functions/exif` | native JPEG EXIF (Make/Model/DateTime/Orientation) |
| `tags.py` | `functions/tags` | native ID3v1 + ID3v2 MP3 tags |
| `compression.py` | `functions/compression` | zip/tar entry inspection via stdlib |
| `system.py` | `functions/system` | freedesktop trash, shred, undo replay |
| `core.py` | `functions/core` | engine re-exports (template + organizer) |
| `deps.py` | `functions/deps` | interpreter checks (no binary deps exist) |
| `docs.py` | `functions/docs` | man page + lineage feature map |
| `editions.py` | (versions engine) | per-edition capability gating |
| `testing.py` | self-tests | `python3 -m functions` |

The fast engine itself lives in `../Sort.py` (self-contained single file,
imported here as the base). `ffmpeg` has no direct native equivalent;
`functions/mime` covers container sniffing only, as documented in the main
README.

## Self-test

```bash
python3 -m functions          # engine suite + module suite (exif, id3, zip, eras)
Sort.py --self-test           # engine-only suite
python3 versions/Media-Intelligent/Sort-V7.py --dirs=exif-make image.jpg
```
