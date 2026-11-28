Get_File_Birth() {
	local Time
	Time=$(stat -c '%W' -- "$1" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
