Get_File_Creation_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%w' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
