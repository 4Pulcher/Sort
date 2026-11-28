Dir_Minus_Content() {
	local DirA=${1%/}
	local DirB=${2%/}
	local Algo=${3:-sha256}
	local BHashes PathA PathB Hash Sum

	[ -d "$DirA" ] && [ -d "$DirB" ] || return 1

	# Hash every file in B once, keep the unique set.
	BHashes=$(
		find "$DirB" -type f -print0 2>/dev/null |
			while IFS= read -r -d '' PathB; do
				Hash=$(Get_Hash "$Algo" "$PathB" 2>/dev/null) && printf '%s\n' "$Hash"
			done | LC_ALL=C sort -u
	)

	find "$DirA" -type f -print0 2>/dev/null |
		while IFS= read -r -d '' PathA; do
			Sum=$(Get_Hash "$Algo" "$PathA") || continue
			# An empty B matches nothing, so every file of A is reported.
			if [ -n "$BHashes" ] && printf '%s\n' "$BHashes" | grep -qx "$Sum"; then
				continue
			fi
			printf '%s\n' "$PathA"
		done
}
