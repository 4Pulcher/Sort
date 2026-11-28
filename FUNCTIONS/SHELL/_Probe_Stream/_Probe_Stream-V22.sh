_Probe_Stream() {
	local Out

	_FF_Have ffprobe || return 127

	Out=$(_FF_Run "$2" "$1" "$3")
	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}
