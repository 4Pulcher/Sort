Get_File_Access_Time() {
	local File=$1
	stat -c '%x' -- "$File" 2>/dev/null
}
