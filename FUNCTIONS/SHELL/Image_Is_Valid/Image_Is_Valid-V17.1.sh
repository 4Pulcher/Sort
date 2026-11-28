Image_Is_Valid() {
	local File=$1

	[ -f "$File" ] || return 1
	_IM_Identify '%m' "$File" >/dev/null
}
