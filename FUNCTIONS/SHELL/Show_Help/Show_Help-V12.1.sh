Show_Help() {
	Draw_Line '━'
	cat <<'EOF'
Sort.sh v2.3 - Organizer with --colors and --log support
USAGE:
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY ...

NEW OPTIONS:
  --colors          Enables colored screen output.
  --log             Creates a log file: 'Sort ~ YYYY-MM-DD.log' in working directory.
  --jobs=N          Concurrent threads (default: 4).
EOF
	Draw_Line '━'
}
