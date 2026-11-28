Get_File_Header_Hex() {
	local File=$1
	local Bytes=${2:-8}
	local Hex

	[ -f "$File" ] || return 1
	command -v od >/dev/null || return 127

	Hex=$(od -An -tx1 -N "$Bytes" -- "$File" 2>/dev/null | tr -d ' \n')
	printf '%s' "$Hex"
}
