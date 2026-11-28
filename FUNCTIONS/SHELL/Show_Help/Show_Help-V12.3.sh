Show_Help() {
	cat <<'EOF'
================================================================================
Sort.sh v2.5 - Media-Intelligent File Organizer (ExifTool Integration)
Developed by: HEjder
================================================================================

USAGE:
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

OPERATIONAL MODES:
  --mode=copy       Copy files to calculated destination.
  --mode=move       Move files to calculated destination.
  --mode=delete     Permanently delete target file (alias: --mode=remove).
  --mode=trash      Send target file to system trash (requires trash-cli).
  --mode=shred      Securely overwrite and delete target file.

DISPLAY, LOGGING & THREADING:
  --jobs=N          Number of concurrent worker threads (default: 4).
  --colors          Enable high-contrast ANSI colors for dark/light terminals.
  --log             Write a plain-text log to './Sort ~ YYYY-MM-DD.log'.

METADATA PREFERENCE:
  ExifTool is now the primary provider for:
    - Dates & Timestamps (DateTimeOriginal, CreateDate, ModifyDate)
    - Media Tags (Artist, Album, Title, ImageSize/Dimensions)
    - Automatically falls back to ffprobe/stat when tags are absent.
================================================================================
EOF
}
