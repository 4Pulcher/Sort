Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	# Dry-run mode is the default and never modifies the filesystem.
	if [[ -z "$Mode" ]]; then
		printf '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	# Ensure the destination directory exists for copy and move operations.
	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}"; then
			printf '%bERROR:%b Could not create destination directory.\n' "$RED" "$RESET"
			return 1
		fi
	fi

	# Resolve both paths before destructive operations to avoid acting on the
	# source file by accident when source and destination refer to the same file.
	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)

		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				printf '%bERROR:%b Source and target are the same file; refusing destructive action: %s\n' \
					"$RED" "$RESET" "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	# Execute the selected action. -- prevents paths beginning with "-" from
	# being interpreted as command-line options by the external utility.
	case "$Mode" in
	copy)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			printf '%bERROR:%b Destination already exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		fi
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			printf '%bERROR:%b Destination already exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		fi
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		if [[ -e "$TargetPath" ]]; then
			rm -v -f -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	trash)
		if [[ -e "$TargetPath" ]]; then
			trash-put -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	shred)
		if [[ -e "$TargetPath" ]]; then
			shred -u -n 1 -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	esac
}
