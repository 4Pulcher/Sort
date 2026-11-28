Get_File_Birth() {
	local File=$1
	local Time

	Time=$(stat -c '%W' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
