Get_SHA1Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha1sum >/dev/null || return 127

	Sum=$(sha1sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}
