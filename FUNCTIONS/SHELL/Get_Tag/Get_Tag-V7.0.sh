Get_Tag() {
	ffprobe -v error -show_entries "$2" -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}
