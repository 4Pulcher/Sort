Get_Image_DPI() {
	local File=$1
	local X Y

	X=$(_IM_Identify '%x' "$File") || return $?
	Y=$(_IM_Identify '%y' "$File") || return $?
	printf '%sx%s' "${X%% *}" "${Y%% *}"
}
