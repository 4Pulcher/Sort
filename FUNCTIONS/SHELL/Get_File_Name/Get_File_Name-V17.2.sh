Get_File_Name() {
	local Name=${1##*/}
	printf '%s' "${Name%.*}"
}
