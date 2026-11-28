Get_MIME_Charset() {
	local File=$1
	local Charset

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Charset=$(file -b --mime-encoding -- "$File" 2>/dev/null)
	[ -n "$Charset" ] || return 1
	printf '%s' "$Charset"
}
