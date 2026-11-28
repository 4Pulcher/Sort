Get_File_Access_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%x' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
