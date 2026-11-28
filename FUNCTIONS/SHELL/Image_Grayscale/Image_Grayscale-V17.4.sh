Image_Grayscale() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -colorspace Gray "$Out"
}
