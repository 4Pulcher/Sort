Collect_Files() {
	local Item File

	for Item in "${Files[@]}"; do
		if [ -d "$Item" ]; then
			# A directory: every regular file below it joins the array
			while IFS= read -r -d '' File; do
				Targets+=("$File")
			done < <(find "$Item" -type f -print0 2>/dev/null)
		elif [ -f "$Item" ]; then
			Targets+=("$Item")
		else
			Print_Warning "Not a file or directory: $Item"
		fi
	done

	[ "$Quiet" -eq 1 ] || Print_Info "Files to treat: ${#Targets[@]}"
}
