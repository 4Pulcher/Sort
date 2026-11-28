Get_B2Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v b2sum >/dev/null || return 127

	Sum=$(b2sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}
