File_Is_Binary() {
	[[ "$(Get_File_Encoding "$1" 2>/dev/null)" == "binary" ]]
}
