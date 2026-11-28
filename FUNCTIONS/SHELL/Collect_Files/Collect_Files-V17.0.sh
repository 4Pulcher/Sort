Collect_Files() {
	local Item File StartBase
	local -a Dir_Args

	for Item in "${Files[@]}"; do
		if [ -d "$Item" ]; then
			# Depth: full walk with --recursive, top level only otherwise
			Dir_Args=()
			[ "$Recursive" -eq 1 ] || Dir_Args+=(-maxdepth 1)

			# Hidden entries are pruned unless --hidden; the start point
			# itself (which may be named .* too) must never be pruned
			if [ "$Hidden" -eq 0 ]; then
				StartBase=${Item##*/}
				[ -n "$StartBase" ] || StartBase=$Item
				Dir_Args+=(-name '.*' ! -path "$Item" ! -name "$StartBase" -prune -o)
			fi

			# Regular files, plus symlinks with --links
			if [ "$Links" -eq 1 ]; then
				Dir_Args+=(\( -type f -o -type l \) -print0)
			else
				Dir_Args+=(-type f -print0)
			fi

			while IFS= read -r -d '' File; do
				Targets+=("$File")
			done < <(find "$Item" "${Dir_Args[@]}" 2>/dev/null)
		elif [ -f "$Item" ] || { [ "$Links" -eq 1 ] && [ -L "$Item" ]; }; then
			Targets+=("$Item")
		else
			Print_Warning "Not a file or directory: $Item"
		fi
	done

	[ "$Quiet" -eq 1 ] || Print_Info "Files to treat: ${#Targets[@]}"
}
