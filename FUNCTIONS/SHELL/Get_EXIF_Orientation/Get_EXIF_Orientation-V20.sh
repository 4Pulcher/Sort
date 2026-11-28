Get_EXIF_Orientation() {
	local File=$1
	local Orientation

	Orientation=$(_Exif_Read Orientation "$File") || return $?
	printf '%s' "$Orientation"
}
