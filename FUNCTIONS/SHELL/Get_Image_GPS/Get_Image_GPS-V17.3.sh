Get_Image_GPS() {
	local File=$1
	local Lat Lon

	Lat=$(_IM_Identify '%[exif:GPSLatitude]' "$File") || Lat=''
	Lon=$(_IM_Identify '%[exif:GPSLongitude]' "$File") || Lon=''

	[ -n "$Lat" ] || [ -n "$Lon" ] || return 1
	printf '%s,%s' "$Lat" "$Lon"
}
