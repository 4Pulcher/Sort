Get_Image_Width() {
	local File=$1
	local Width

	Width=$(_IM_Identify '%w' "$File") || return $?
	printf '%s' "$Width"
}
