Get_MIME_Type() {
	local File=$1
	local MIME

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	[ -n "$MIME" ] || return 1
	printf '%s' "$MIME"
}
