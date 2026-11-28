Get_File_Modification_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
