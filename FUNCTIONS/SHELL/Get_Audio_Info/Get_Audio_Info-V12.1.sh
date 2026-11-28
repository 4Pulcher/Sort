Get_Audio_Info() {
	local File=$1
	local Artist Album Title Info=""
	Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	Album=$(timeout 10s ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	Title=$(timeout 5s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Album" ]] && Info="${Info:+$Info - }$Album"
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"
	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}
