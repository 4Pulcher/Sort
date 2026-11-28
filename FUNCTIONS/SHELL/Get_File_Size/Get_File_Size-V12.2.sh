Get_File_Size() {
	local Size
	Size=$(stat -c '%s' -- "$1" 2>/dev/null)
	printf '%d' "${Size:-0}"
}
