Get_EXIF_Exposure() {
	local File=$1
	local Exposure

	Exposure=$(_Exif_Read ExposureTime "$File") || return $?
	printf '%s' "$Exposure"
}
