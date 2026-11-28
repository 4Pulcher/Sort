Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	if [[ -z "$Mode" ]]; then
		Log_Print '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		mkdir -p -- "${TargetPath%/*}" || {
			Log_Print 'ERROR: Could not create dir.\n'
			return 1
		}
	fi

	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)
		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				Log_Print 'ERROR: Source and target are same file; refusing: %s\n' "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	case "$Mode" in
	copy)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			Log_Print 'ERROR: Exists: %s\n' "$TargetPath"
			return 1
		}
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			Log_Print 'ERROR: Exists: %s\n' "$TargetPath"
			return 1
		}
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		[[ -e "$TargetPath" ]] && rm -v -f -- "$TargetPath" || Log_Print 'File not found: %s\n' "$TargetPath"
		;;
	trash)
		[[ -e "$TargetPath" ]] && trash-put -- "$TargetPath" || Log_Print 'File not found: %s\n' "$TargetPath"
		;;
	shred)
		[[ -e "$TargetPath" ]] && shred -u -n 1 -- "$TargetPath" || Log_Print 'File not found: %s\n' "$TargetPath"
		;;
	esac
}
