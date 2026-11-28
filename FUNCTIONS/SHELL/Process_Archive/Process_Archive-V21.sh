Process_Archive() {
	local File=$1
	local Tmp SavedModus Count=0 Inner

	Status='FAILED'

	[ "$Decompress_Depth" -lt 8 ] || {
		Print_Error "$(Tf 'Decompression too deep: %s' "$File")"
		return 1
	}

	# Extract + test: a failing archive is never touched further
	Archive_Test "$File" || {
		Print_Error "$(Tf 'Archive test failed: %s' "$File")"
		return 1
	}

	Tmp=$(mktemp -d) || return 1
	Archive_Extract "$File" "$Tmp" || {
		Print_Error "$(Tf 'Extract failed: %s' "$File")"
		rm -rf -- "$Tmp"
		return 1
	}

	# In action modes the contents are always sorted with copy semantics; the
	# mode only decides the fate of the archive itself. Preview stays preview.
	SavedModus=$Modus
	case "$Modus" in
	Print) ;;
	*) Modus='Copy' ;;
	esac

	while IFS= read -r -d '' Inner; do
		Decompress_Depth=$((Decompress_Depth + 1))
		Process_File "$Inner"
		Decompress_Depth=$((Decompress_Depth - 1))
		Count=$((Count + 1))
	done < <(find "$Tmp" -mindepth 1 -type f -print0 | sort -z)

	Modus=$SavedModus
	rm -rf -- "$Tmp"

	# Fate of the archive itself
	case "$Modus" in
	Print)
		Status='PREVIEW'
		Print_Message "$(Tf 'EXTRACT(%s): %s <=> delete archive' "$Count" "$File")"
		;;
	Trash)
		Deps_Ensure trash-put || {
			Status='FAILED'
			Print_Error 'Trash needs trash-put (trash-cli)'
			return 1
		}
		if trash-put -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "$(Tf 'Extracted(%s) + trashed: %s' "$Count" "$File")"
			Log_Action "TRASH $File"
		else
			Status='FAILED'
			Print_Error "$(Tf 'Trash failed: %s' "$File")"
			return 1
		fi
		;;
	Shred)
		if shred -u -n 1 -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "$(Tf 'Extracted(%s) + shredded: %s' "$Count" "$File")"
			Log_Action "SHRED $File"
		else
			Status='FAILED'
			Print_Error "$(Tf 'Shred failed: %s' "$File")"
			return 1
		fi
		;;
	*)
		if rm -v -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "$(Tf 'Extracted(%s) + deleted: %s' "$Count" "$File")"
			Log_Action "DELETE $File"
		else
			Status='FAILED'
			Print_Error "$(Tf 'Delete failed: %s' "$File")"
			return 1
		fi
		;;
	esac

	return 0
}
