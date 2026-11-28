EXIF_Is_Present() {
	local File=$1

	[ -f "$File" ] || return 1
	Get_EXIF_All "$File" >/dev/null
}
