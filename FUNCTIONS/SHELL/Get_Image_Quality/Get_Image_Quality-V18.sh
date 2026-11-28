Get_Image_Quality() {
	local File=$1
	local Quality

	Quality=$(_IM_Identify '%Q' "$File") || return $?
	printf '%s' "$Quality"
}
