Files_Are_Identical() {
	local A=$1
	local B=$2

	[ -f "$A" ] && [ -f "$B" ] || return 1
	cmp -s -- "$A" "$B"
}
