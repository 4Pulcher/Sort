_Probe() {
	local Out

	_FF_Have ffprobe || return 127

	Out=$(_FF_Run '' "$1" "$2")
	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}
