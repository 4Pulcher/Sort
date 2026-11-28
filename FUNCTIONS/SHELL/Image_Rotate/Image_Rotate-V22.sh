Image_Rotate() {
	local In=$1
	local Degrees=$2
	local Out=$3

	[ -f "$In" ] && [ -n "$Degrees" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -rotate "$Degrees" "$Out"
}
