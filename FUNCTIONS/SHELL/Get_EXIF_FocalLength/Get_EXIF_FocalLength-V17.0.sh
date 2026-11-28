Get_EXIF_FocalLength() {
	local File=$1
	local Focal

	Focal=$(_Exif_Read FocalLength "$File") || return $?
	printf '%s' "$Focal"
}
