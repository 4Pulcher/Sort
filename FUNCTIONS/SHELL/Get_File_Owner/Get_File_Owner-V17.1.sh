Get_File_Owner() {
	local File=$1
	local Owner

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Owner=$(stat -c '%U:%G' -- "$File" 2>/dev/null)
	printf '%s' "${Owner:-ERROR}"
}
