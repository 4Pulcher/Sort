Get_SHA384Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha384sum >/dev/null || return 127

	Sum=$(sha384sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}
