Image_Thumbnail() {
	local In=$1
	local Size=${2:-256x256}
	local Out=$3

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -thumbnail "$Size" "$Out"
}
