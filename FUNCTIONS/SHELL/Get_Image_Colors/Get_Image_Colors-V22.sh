Get_Image_Colors() {
	local File=$1
	local Colors

	Colors=$(_IM_Identify '%k' "$File") || return $?
	printf '%s' "$Colors"
}
