Show_Help() {
	Draw_Line '━'
	cat <<'EOF'
Sort.sh v2.2 - Media-Intelligent File Organizer with --jobs=N Threading
Organizes files using MIME information, filesystem timestamps and metadata.

USAGE
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

OPERATION MODES
  --mode=copy       Copy files to calculated destination.
  --mode=move       Move files to calculated destination.
  --mode=delete     Permanently delete target file.
  --mode=trash      Send target file to desktop trash.
  --mode=shred      Securely overwrite and delete target file.

PROCESSING & THREADING
  --jobs=N          Run up to N tasks in parallel (default: 4).
  --type=VALUE      Filter files by MIME type (e.g. image, video, pdf).
  --recursive       Process subdirectories recursively.
  --pause=SEC       Wait specified seconds after each file action.

DESTINATION & NAMING
  --dirs=OPT        Primary directory structure pattern.
  --subdirs=OPT     Secondary subdirectory pattern.
  --rename=OPT      Override filename with dynamic value.
  --extension=OPT   Override file extension with dynamic value.
  --title           Extract smart metadata for titles (Video, Audio, Image, PDF).
  --replace         Overwrite existing files at destination.

EOF
	Draw_Line '━'
}
