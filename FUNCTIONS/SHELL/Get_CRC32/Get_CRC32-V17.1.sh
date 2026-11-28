Get_CRC32() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v cksum >/dev/null || return 127

	Sum=$(cksum -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}
