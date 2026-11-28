Media_Is_Valid() {
	local File=$1

	[ -f "$File" ] || return 1
	_FF_Have ffprobe || return 127

	timeout 10s ffprobe -v error -- "$File" >/dev/null 2>&1
}
