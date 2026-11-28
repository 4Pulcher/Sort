Get_MIME_Description() {
	local File=$1
	local Desc

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Desc=$(file -b -- "$File" 2>/dev/null)
	[ -n "$Desc" ] || return 1
	printf '%s' "$Desc"
}
