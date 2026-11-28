Get_File_Size_Human() {
	local Size

	Size=$(Get_File_Size "$1") || return 1
	Human_From_Bytes "$Size"
}
