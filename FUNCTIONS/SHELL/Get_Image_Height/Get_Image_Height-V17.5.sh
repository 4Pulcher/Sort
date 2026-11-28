Get_Image_Height() {
	local File=$1
	local Height

	Height=$(_IM_Identify '%h' "$File") || return $?
	printf '%s' "$Height"
}
