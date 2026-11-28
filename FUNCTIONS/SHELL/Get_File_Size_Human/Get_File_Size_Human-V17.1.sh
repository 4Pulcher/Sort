Get_File_Size_Human() {
	local File=$1
	local Size

	[ -e "$File" ] || return 1
	command -v du >/dev/null || return 127

	Size=$(du -h -- "$File" 2>/dev/null | cut -f1)
	printf '%s' "${Size:-ERROR}"
}
