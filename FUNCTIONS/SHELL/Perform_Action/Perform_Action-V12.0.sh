Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	if [[ -z "$Mode" ]]; then
		printf '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}"; then
			printf '%bERROR:%b Could not create destination directory.\n' "$RED" "$RESET"
			return 1
		fi
	fi

	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)

		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				printf '%bERROR:%b Source and target are same file; refusing destructive action: %s\n' \
					"$RED" "$RESET" "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	case "$Mode" in
	copy)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			printf '%bERROR:%b Destination exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		}
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			printf '%bERROR:%b Destination exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		}
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		[[ -e "$TargetPath" ]] && rm -v -f -- "$TargetPath" || {
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		}
		;;
	trash)
		[[ -e "$TargetPath" ]] && trash-put -- "$TargetPath" || {
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		}
		;;
	shred)
		[[ -e "$TargetPath" ]] && shred -u -n 1 -- "$TargetPath" || {
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		}
		;;
	esac
}
