Get_EXIF_GPS() {
	local File=$1
	local Lat Lon

	_Exif_Has_Reader || return 127
	Lat=$(Get_EXIF_GPS_Lat "$File") || Lat=''
	Lon=$(Get_EXIF_GPS_Lon "$File") || Lon=''

	[ -n "$Lat" ] || [ -n "$Lon" ] || return 1
	printf '%s,%s' "$Lat" "$Lon"
}
