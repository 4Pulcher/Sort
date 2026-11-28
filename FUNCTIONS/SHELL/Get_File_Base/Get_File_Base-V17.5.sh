Get_File_Base() {
	local Name=${1##*/}
	printf '%s' "$Name"
}
