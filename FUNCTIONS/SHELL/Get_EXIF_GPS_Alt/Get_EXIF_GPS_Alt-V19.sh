Get_EXIF_GPS_Alt() {
	local File=$1
	local Alt

	Alt=$(_Exif_Read GPSAltitude "$File") || return $?
	printf '%s' "$Alt"
}
