Dir_Minus() {
	local DirA=${1%/}
	local DirB=${2%/}
	local PathA Rel

	[ -d "$DirA" ] && [ -d "$DirB" ] || return 1

	find "$DirA" -type f -print0 2>/dev/null |
		while IFS= read -r -d '' PathA; do
			Rel=${PathA#"$DirA"/}
			[ -e "$DirB/$Rel" ] || printf '%s\n' "$Rel"
		done
}
