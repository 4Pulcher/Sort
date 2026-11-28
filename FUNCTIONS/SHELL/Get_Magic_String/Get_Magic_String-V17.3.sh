Get_Magic_String() {
	local File=$1
	local Count=${2:-16}
	local Str

	[ -f "$File" ] || return 1
	[ "$Count" -gt 0 ] 2>/dev/null || return 1
	command -v head >/dev/null || return 127

	Str=$(head -c "$Count" -- "$File" 2>/dev/null | tr -c '[:print:]' '.')
	[ -n "$Str" ] || return 1
	printf '%s' "$Str"
}
