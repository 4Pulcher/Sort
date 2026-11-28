Get_Date_Part() {
	local T
	T=$(Get_File_Birth "$1")
	[[ "$T" != "0" ]] && date -d "@$T" "$2" 2>/dev/null || printf "%s" "$3"
}
