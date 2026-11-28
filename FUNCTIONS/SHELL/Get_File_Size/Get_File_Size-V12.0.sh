Get_File_Size() {
	local File=$1
	local Size
	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}
