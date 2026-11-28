Get_Magic_Bytes() {
	local File=$1
	local Count=${2:-16}
	local Hex

	[ -f "$File" ] || return 1
	[ "$Count" -gt 0 ] 2>/dev/null || return 1
	command -v od >/dev/null || return 127

	Hex=$(od -An -v -tx1 -N "$Count" -- "$File" 2>/dev/null | tr -s ' \n' ' ')
	Hex=${Hex# }
	Hex=${Hex% }
	[ -n "$Hex" ] || return 1
	printf '%s' "$Hex"
}
