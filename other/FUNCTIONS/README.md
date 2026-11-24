# FUNCTIONS

> Legacy helper library for the main `Sort.sh` (V15.1)

The original `FUNCTIONS/` directory that V15.1 sourced was never part of the
upload batch, so it was rebuilt here as a thin compatibility layer over the
modern [`functions/`](functions/README.md) toolkit. Each module adapts the
lowercase `get_*` names the main script expects; every adapter prints its
result on stdout and returns non-zero on failure (127 = required tool
missing).

| Module | Provides | Built on |
|---|---|---|
| [get_file.sh](get_file.sh) | `get_file_sha256sum`, `get_file_name_long`, `get_file_name`, `get_file_folder`, `get_file_extension`, `get_file_size_Category`, `get_file_size_short` | `functions/file`, `functions/hash` |
| [get_mime.sh](get_mime.sh) | `get_mime`, `get_mime_sub`, `get_mime_MAIN`, `get_MIME` | `functions/mime` |
| [get_image_exif.sh](get_image_exif.sh) | `get_image_dimension`, `get_image_size_Category`, `get_image_size_Form` | `functions/imagemagick` |
| [get_video_exif.sh](get_video_exif.sh) | `get_video_dimention`, `get_video_duration` | `functions/ffmpeg` |

## Consumers

- `Sort.sh` (repository root) — sources `${0%/*}/FUNCTIONS/*.sh`
- `versions/V15.1/Sort-V15.1.sh` — sources `../../FUNCTIONS/*.sh`

## Notes

- The image adapters need ImageMagick (`identify`/`magick`), the video
  adapters need `ffprobe`; when missing they return 127 (and propose an
  install if the `functions/deps` module is loaded).
- `get_file_folder` returns the *name* of the containing folder, so the
  V15.1 rename pattern `$folder_$filename` stays a flat, filename-safe name.
- `get_MIME` returns the full MIME type, used as the top-level directory
  (`image/png/...`); `get_mime_MAIN` returns the upper-cased main type for
  branching (`IMAGE`, `VIDEO`, ...).
