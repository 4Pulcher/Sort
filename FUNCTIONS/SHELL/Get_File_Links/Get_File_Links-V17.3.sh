Get_File_Links() {
	local File=$1
	local Links

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Links=$(stat -c '%h' -- "$File" 2>/dev/null)
	printf '%s' "${Links:-ERROR}"
}
