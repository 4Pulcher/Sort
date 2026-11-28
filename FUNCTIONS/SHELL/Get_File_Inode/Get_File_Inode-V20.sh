Get_File_Inode() {
	local File=$1
	local Inode

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Inode=$(stat -c '%i' -- "$File" 2>/dev/null)
	printf '%s' "${Inode:-ERROR}"
}
