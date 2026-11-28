Get_File_Size() {
	local File=$1
	local Size

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}
