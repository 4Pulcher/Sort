Get_MD5Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v md5sum >/dev/null || return 127

	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}
