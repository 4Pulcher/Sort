Get_Audio_Info() {
	local T
	T=$(timeout 5s ffprobe -v error -show_entries format_tags=artist,title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | tr '
' '-' | sed 's/-$//')
	[[ -z "$T" ]] && Get_File_Name "$1" || Sanitize "$T"
}
