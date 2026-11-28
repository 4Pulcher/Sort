Get_EXIF_Artist() {
	local File=$1
	local Artist

	Artist=$(_Exif_Read Artist "$File") || return $?
	printf '%s' "$Artist"
}
