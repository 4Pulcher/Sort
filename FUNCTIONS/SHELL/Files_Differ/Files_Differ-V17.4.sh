Files_Differ() {
	local A=$1
	local B=$2

	[ -f "$A" ] && [ -f "$B" ] || return 1
	command -v cmp >/dev/null || return 127

	! cmp -s -- "$A" "$B"
}
