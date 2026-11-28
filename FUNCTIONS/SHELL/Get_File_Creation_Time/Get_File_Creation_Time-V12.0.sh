Get_File_Creation_Time() {
	local File=$1
	stat -c '%w' -- "$File" 2>/dev/null
}
