Get_File_Block_Size() {
	local File=$1
	local Size

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Size=$(stat -c '%b * %B' -- "$File" 2>/dev/null)
	[ -n "$Size" ] || return 1
	echo $((Size))
}
