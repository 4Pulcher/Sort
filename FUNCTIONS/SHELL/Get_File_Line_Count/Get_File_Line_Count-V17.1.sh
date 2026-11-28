Get_File_Line_Count() {
	local File=$1
	local Count

	[ -f "$File" ] || return 1
	command -v wc >/dev/null || return 127

	Count=$(wc -l <"$File" 2>/dev/null)
	printf '%d' "${Count:-0}"
}
