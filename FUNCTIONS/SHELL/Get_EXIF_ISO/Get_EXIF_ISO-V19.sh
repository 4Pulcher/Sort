Get_EXIF_ISO() {
	local File=$1
	local Iso

	Iso=$(_Exif_Read ISO "$File") || return $?
	printf '%s' "$Iso"
}
