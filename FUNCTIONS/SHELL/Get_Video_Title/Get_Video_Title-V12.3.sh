Get_Video_Title() {
	local File=$1
	local Title Artist Info=""

	Title=$(Get_Exif_Tag "$File" Title)
	Artist=$(Get_Exif_Tag "$File" Artist)

	[[ -z "$Title" ]] && Title=$(timeout 10s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	[[ -z "$Artist" ]] && Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)

	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"

	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}
