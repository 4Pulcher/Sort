Get_EXIF_All() {
	local File=$1
	local Dump

	[ -f "$File" ] || return 1
	_Exif_Have exiftool || return 127

	Dump=$(timeout 10s exiftool -s -- "$File" 2>/dev/null)
	[ -n "$Dump" ] || return 1
	printf '%s\n' "$Dump"
}
