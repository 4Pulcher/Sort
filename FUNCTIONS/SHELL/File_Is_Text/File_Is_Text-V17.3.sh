File_Is_Text() {
	[[ "$(Get_File_Encoding "$1" 2>/dev/null)" != "binary" ]]
}
