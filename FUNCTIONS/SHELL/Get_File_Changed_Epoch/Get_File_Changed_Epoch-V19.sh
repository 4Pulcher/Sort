Get_File_Changed_Epoch() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%Z' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}
