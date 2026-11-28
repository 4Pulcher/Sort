Get_Exif_Tag() {
	local File=$1
	local TagName=$2
	exiftool -s -s -s -"$TagName" "$File" 2>/dev/null
}
