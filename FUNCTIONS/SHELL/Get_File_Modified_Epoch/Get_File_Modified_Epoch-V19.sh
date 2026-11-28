Get_File_Modified_Epoch() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%Y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
