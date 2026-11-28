Get_EXIF_Tags() {
	local File=$1
	local Tags

	Tags=$(Get_EXIF_All "$File") || return $?
	printf '%s\n' "$Tags" | sed 's/ :.*//' | grep -v '^$'
}
