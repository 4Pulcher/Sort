Get_File_Access_Time() {
	stat -c '%x' -- "$1" 2>/dev/null
}
