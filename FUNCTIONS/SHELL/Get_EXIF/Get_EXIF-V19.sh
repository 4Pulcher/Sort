Get_EXIF() {
	local Tag=$1
	local File=$2

	[ -n "$Tag" ] && [ -f "$File" ] || return 1
	_Exif_Read "$Tag" "$File"
}
