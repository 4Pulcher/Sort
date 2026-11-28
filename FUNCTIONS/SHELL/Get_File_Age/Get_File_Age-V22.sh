Get_File_Age() {
	local File=$1
	local Now Modified

	Modified=$(Get_File_Modified_Epoch "$File") || return 1
	[[ "$Modified" == "0" ]] && return 1
	Now=$(date +%s)
	printf '%d' "$((Now - Modified))"
}
