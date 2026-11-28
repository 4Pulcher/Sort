Get_File_Modification_Time() {
	local File=$1
	stat -c '%y' -- "$File" 2>/dev/null
}
