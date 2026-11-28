Get_SHA224Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha224sum >/dev/null || return 127

	Sum=$(sha224sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}
