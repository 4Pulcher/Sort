Exif_Camera_Dir() {
	local Cam

	Cam=$(Get_EXIF_Camera "$1" 2>/dev/null) || return 1
	Cam=$(Sanitize_Name "$Cam")
	[ -n "$Cam" ] || return 1
	printf '%s' "$Cam"
}
