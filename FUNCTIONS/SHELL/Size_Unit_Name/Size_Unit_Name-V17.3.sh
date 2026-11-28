Size_Unit_Name() {
	local Size

	Size=$(Get_File_Size "$1") || return 1
	Size_Unit_From_Bytes "$Size"
}
