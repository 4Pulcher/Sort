Image_Resize() {
	local In=$1
	local Size=$2
	local Out=$3

	[ -f "$In" ] && [ -n "$Size" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -resize "$Size" "$Out"
}
