Get_Audio_Info() {
	local File=$1
	local Artist Album Title Info=""

	Artist=$(Get_Exif_Tag "$File" Artist)
	Album=$(Get_Exif_Tag "$File" Album)
	Title=$(Get_Exif_Tag "$File" Title)

	# Fallback to ffprobe if tags are missing via ExifTool
	if [[ -z "$Artist" ]]; then
		Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	fi
	if [[ -z "$Album" ]]; then
		Album=$(timeout 10s ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	fi
	if [[ -z "$Title" ]]; then
		Title=$(timeout 5s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	fi

	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Album" ]] && Info="${Info:+$Info - }$Album"
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"

	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}
