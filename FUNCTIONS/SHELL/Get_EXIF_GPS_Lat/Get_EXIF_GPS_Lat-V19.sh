Get_EXIF_GPS_Lat() {
	local File=$1
	local Lat

	if command -v exiftool >/dev/null; then
		Lat=$(timeout 10s exiftool -s3 -c '%.6f' -GPSLatitude -- "$File" 2>/dev/null)
	else
		Lat=$(_Exif_Read GPSLatitude "$File") || return $?
	fi

	[ -n "$Lat" ] || return 1
	printf '%s' "$Lat"
}
