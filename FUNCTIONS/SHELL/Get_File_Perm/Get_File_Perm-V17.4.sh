Get_File_Perm() {
	local File=$1
	local Perm

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Perm=$(stat -c '%a' -- "$File" 2>/dev/null)
	printf '%s' "${Perm:-ERROR}"
}
