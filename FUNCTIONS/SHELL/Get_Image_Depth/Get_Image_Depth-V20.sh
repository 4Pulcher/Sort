Get_Image_Depth() {
	local File=$1
	local Depth

	Depth=$(_IM_Identify '%z' "$File") || return $?
	printf '%s' "$Depth"
}
