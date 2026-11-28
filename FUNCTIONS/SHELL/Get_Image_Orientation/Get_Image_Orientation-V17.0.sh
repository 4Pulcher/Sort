Get_Image_Orientation() {
	local File=$1
	local Orientation

	Orientation=$(_IM_Identify '%[orientation]' "$File") || return $?
	printf '%s' "$Orientation"
}
