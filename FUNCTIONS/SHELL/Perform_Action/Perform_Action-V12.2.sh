Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SlotID=$3
	local SourceReal TargetReal

	# Dry-Run Preview
	if [[ -z "$Mode" ]]; then
		Update_Thread_Slot "$SlotID" "DRY-RUN" "$BLUE" "$SourcePath -> $TargetPath"
		Write_Log "TEST: $SourcePath -> $TargetPath"
		return 0
	fi

	# Create target directories for copy/move
	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Failed creating dir: ${TargetPath%/*}"
			Write_Log "ERROR: Could not create directory for $TargetPath"
			return 1
		fi
	fi

	# Same-file safeguard for destructive operations
	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)
		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				Update_Thread_Slot "$SlotID" "REFUSED" "$RED" "Same file: $SourcePath"
				Write_Log "ERROR: Refusing destructive action on same file: $SourcePath"
				return 1
				;;
			esac
		fi
	fi

	case "$Mode" in
	copy)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			Update_Thread_Slot "$SlotID" "EXISTS" "$YELLOW" "$TargetPath"
			Write_Log "SKIP (EXISTS): $TargetPath"
			return 1
		fi
		if cp -f -- "$SourcePath" "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "COPIED" "$GREEN" "$TargetPath"
			Write_Log "COPY: $SourcePath -> $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Copy failed: $SourcePath"
			Write_Log "ERROR: Copy failed for $SourcePath"
		fi
		;;
	move)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			Update_Thread_Slot "$SlotID" "EXISTS" "$YELLOW" "$TargetPath"
			Write_Log "SKIP (EXISTS): $TargetPath"
			return 1
		fi
		if mv -f -- "$SourcePath" "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "MOVED" "$GREEN" "$TargetPath"
			Write_Log "MOVE: $SourcePath -> $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Move failed: $SourcePath"
			Write_Log "ERROR: Move failed for $SourcePath"
		fi
		;;
	delete | remove)
		if [[ -e "$TargetPath" ]] && rm -f -- "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "DELETED" "$RED" "$TargetPath"
			Write_Log "DELETE: $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "MISSING" "$YELLOW" "$TargetPath"
			Write_Log "WARN: Target not found for delete: $TargetPath"
		fi
		;;
	trash)
		if [[ -e "$TargetPath" ]] && trash-put -- "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "TRASHED" "$RED" "$TargetPath"
			Write_Log "TRASH: $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "MISSING" "$YELLOW" "$TargetPath"
			Write_Log "WARN: Target not found for trash: $TargetPath"
		fi
		;;
	shred)
		if [[ -e "$TargetPath" ]] && shred -u -n 1 -- "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "SHREDDED" "$RED" "$TargetPath"
			Write_Log "SHRED: $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "MISSING" "$YELLOW" "$TargetPath"
			Write_Log "WARN: Target not found for shred: $TargetPath"
		fi
		;;
	esac
}
