Get_EXIF_CreateDate() {
	local File=$1
	local Date

	Date=$(_Exif_Read CreateDate "$File") || return $?
	printf '%s' "$Date"
}
