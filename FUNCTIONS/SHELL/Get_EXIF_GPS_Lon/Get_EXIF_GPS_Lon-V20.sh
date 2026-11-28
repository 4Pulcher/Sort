Get_EXIF_GPS_Lon() {
	local File=$1
	local Lon

	if command -v exiftool >/dev/null; then
		Lon=$(timeout 10s exiftool -s3 -c '%.6f' -GPSLongitude -- "$File" 2>/dev/null)
	else
		Lon=$(_Exif_Read GPSLongitude "$File") || return $?
	fi

	[ -n "$Lon" ] || return 1
	printf '%s' "$Lon"
}
