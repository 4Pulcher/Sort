Get_EXIF_Date() {
	local File=$1
	local Date

	Date=$(_Exif_Read DateTimeOriginal "$File") || return $?
	printf '%s' "$Date"
}
