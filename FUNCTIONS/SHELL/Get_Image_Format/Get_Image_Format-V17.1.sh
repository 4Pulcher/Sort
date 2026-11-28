Get_Image_Format() {
	local File=$1
	local Format

	Format=$(_IM_Identify '%m' "$File") || return $?
	printf '%s' "$Format"
}
