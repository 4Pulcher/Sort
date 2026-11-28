Get_EXIF_Aperture() {
	local File=$1
	local Aperture

	Aperture=$(_Exif_Read FNumber "$File") || return $?
	printf '%s' "$Aperture"
}
