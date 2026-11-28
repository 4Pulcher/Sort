Run_Threads() {
	local Tmp Idx=0 Total=$#
	local -i Done_Copied=0 Done_Moved=0 Done_Preview=0 Done_Skipped=0 Done_Failed=0 Done_Other=0 Done_Extracted=0

	Tmp=$(mktemp -d) || return 1

	# Launch every file, keeping at most Max_Jobs running at once
	while [ "$Idx" -lt "$Total" ]; do
		while [ "$(jobs -rp | wc -l)" -ge "$Max_Jobs" ]; do
			wait -n || true
		done

		(
			Process_File "${@:$((Idx + 1)):1}"
			printf '%s\n' "$Status" >"$Tmp/tag.$Idx"
		) >"$Tmp/out.$Idx" 2>&1 &

		Idx=$((Idx + 1))
	done
	wait

	# Report in submission order so the log stays readable
	for Idx in $(seq 0 $((Total - 1))); do
		[ "$Quiet" -eq 1 ] || cat "$Tmp/out.$Idx"

		case "$(cat "$Tmp/tag.$Idx" 2>/dev/null)" in
		COPIED) Done_Copied+=1 ;;
		MOVED) Done_Moved+=1 ;;
		PREVIEW) Done_Preview+=1 ;;
		SKIPPED) Done_Skipped+=1 ;;
		REMOVED | TRASHED | SHREDDED) Done_Other+=1 ;;
		EXTRACTED) Done_Extracted+=1 ;;
		*) Done_Failed+=1 ;;
		esac
	done

	rm -rf -- "$Tmp"

	# Summary
	printf '\n'
	Print_Header 'Summary'
	Print_Message "Copied : $Done_Copied"
	Print_Message "Moved  : $Done_Moved"
	Print_Message "Removed: $Done_Other"
	Print_Message "Extracted: $Done_Extracted"
	Print_Message "Preview: $Done_Preview"
	Print_Message "Skipped: $Done_Skipped"
	[ "$Done_Failed" -eq 0 ] && Print_Ok "Failed : $Done_Failed" || Print_Error "Failed : $Done_Failed"

	[ "$Done_Failed" -eq 0 ]
}
