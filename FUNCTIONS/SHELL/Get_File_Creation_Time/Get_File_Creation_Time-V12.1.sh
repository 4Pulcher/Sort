Get_File_Creation_Time() {
	stat -c '%w' -- "$1" 2>/dev/null
}
