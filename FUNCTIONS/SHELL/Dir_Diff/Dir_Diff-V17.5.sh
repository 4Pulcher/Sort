Dir_Diff() {
	local DirA=${1%/}
	local DirB=${2%/}
	local Algo=${3:-sha256}
	local PathA PathB Rel HashA HashB

	[ -d "$DirA" ] && [ -d "$DirB" ] || return 1

	{
		find "$DirA" -type f -print0 2>/dev/null |
			while IFS= read -r -d '' PathA; do
				Rel=${PathA#"$DirA"/}
				PathB="$DirB/$Rel"
				if [ ! -e "$PathB" ]; then
					printf 'ONLY_IN_A\t%s\n' "$Rel"
				else
					HashA=$(Get_Hash "$Algo" "$PathA") || continue
					HashB=$(Get_Hash "$Algo" "$PathB") || continue
					if [[ "$HashA" == "$HashB" ]]; then
						printf 'SAME\t%s\n' "$Rel"
					else
						printf 'DIFFERENT\t%s\n' "$Rel"
					fi
				fi
			done

		find "$DirB" -type f -print0 2>/dev/null |
			while IFS= read -r -d '' PathB; do
				Rel=${PathB#"$DirB"/}
				[ -e "$DirA/$Rel" ] || printf 'ONLY_IN_B\t%s\n' "$Rel"
			done
	} | LC_ALL=C sort
}
