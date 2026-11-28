Get_File_Type() {
	local File=$1
	local Type

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Type=$(stat -c '%F' -- "$File" 2>/dev/null)
	printf '%s' "${Type:-ERROR}"
}
