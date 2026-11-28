Get_File_Dir() {
	local Dir=${1%/*}
	[[ "$Dir" == "$1" ]] && Dir='.'
	printf '%s' "$Dir"
}
