Get_File_Encoding() {
	local File=$1
	local Enc

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Enc=$(file -b --mime-encoding -- "$File" 2>/dev/null)
	printf '%s' "${Enc:-ERROR}"
}
