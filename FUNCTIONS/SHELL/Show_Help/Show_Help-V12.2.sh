Show_Help() {
	cat <<'EOF'
================================================================================
Sort.sh v2.4 - Media-Intelligent File Organizer
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
  (Shorthands: --copy, --move, --delete, --remove, --trash, --shred)

DISPLAY, LOGGING & THREADING:
  --jobs=N          Number of concurrent worker threads (default: 4).
  --colors          Enable high-contrast ANSI colors for dark/light terminals.
  --log             Write a plain-text log to './Sort ~ YYYY-MM-DD.log'.

FILTERING & PROCESSING:
  --type=VALUE      Process only files whose MIME type contains VALUE.
  --recursive       Process subdirectories recursively.
  --pause=SECONDS   Wait X seconds after each file action.

DESTINATION & NAMING:
  --dirs=VALUE      Primary directory component (e.g. mime-main, year).
  --subdirs=VALUE   Secondary directory component (e.g. format+size, month).
  --rename=VALUE    Override filename (e.g. sha256sum, md5sum, year).
  --extension=VALUE Override file extension (e.g. extension, mime-sub).
  --title           Extract embedded metadata for titles (Audio/Video/Image/PDF).
  --replace         Overwrite existing destination files instead of numbering.

DYNAMIC VALUES:
  Dates:      year, month, day, year+month, year+month+day, created, modified, accessed
  Identity:   extension, mime, mime-main, mime-sub, md5sum, sha256sum, sha512sum, randomN
  Media/Size: size, format, size+format, format+size
================================================================================
EOF
}
