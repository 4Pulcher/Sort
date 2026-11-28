Sort() {
	local Item
	local -a Children

	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		((Counter[$Current] += 1))

		[[ ! -e "$Item" && ! -L "$Item" ]] && {
			Write_Log "SKIP: Missing $Item"
			continue
		}
		[[ -L "$Item" ]] && {
			Write_Log "SKIP: Symlink $Item"
			continue
		}

		if [[ -d "$Item" ]]; then
			Update_Header_Dir "$Item"
			if [[ "$Recursive" == "yes" ]]; then
				Write_Log "DIR: Entering $Item"
				Children=("$Item"/*)
				((${#Children[@]} > 0)) && Sort "${Children[@]}"

				if [[ "$Mode" == "move" ]]; then
					wait
					rmdir -- "$Item" 2>/dev/null && Write_Log "RMDIR: Removed empty $Item"
				fi
			else
				Write_Log "DIR: Skipping (no --recursive): $Item"
			fi
			continue
		fi

		[[ ! -f "$Item" ]] && continue

		local AssignedSlot
		AssignedSlot=$(Acquire_Slot)

		(
			trap 'Release_Slot "$AssignedSlot"' EXIT

			Update_Thread_Slot "$AssignedSlot" "ANALYZING" "$YELLOW" "$Item"

			local MIME MIMEMain MIMESub
			MIME=$(Get_MIME "$Item")
			MIMEMain=${MIME%%/*}
			MIMESub=${MIME#*/}

			if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
				Update_Thread_Slot "$AssignedSlot" "SKIPPED" "$DIM" "MIME mismatch ($MIME): ${Item##*/}"
				Write_Log "SKIP (MIME $MIME): $Item"
				exit 0
			fi

			local DestinationDir SubDirectory
			if [[ -n "$Dirs" ]]; then
				DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
			else
				DestinationDir=${Item%/*}
				[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
			fi

			SubDirectory=""
			[[ -n "$SubDirs" ]] && SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")

			[[ -z "$DestinationDir" ]] && DestinationDir="."
			[[ -n "$SubDirectory" ]] && DestinationDir="${DestinationDir%/}/$SubDirectory"

			local FileName TemporaryName FileExtension NewName TargetPath
			FileName=$(Get_File_Name "$Item")

			if [[ -n "$Rename" ]]; then
				TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] && FileName=$TemporaryName
			fi

			if [[ "$Title" == "yes" ]]; then
				TemporaryName=""
				case "${MIMEMain,,}" in
				application) TemporaryName=$(Get_Doc_Title "$Item") ;;
				image) TemporaryName=$(Get_Image_Meta "$Item") ;;
				audio) TemporaryName=$(Get_Audio_Info "$Item") ;;
				video) TemporaryName=$(Get_Video_Title "$Item") ;;
				esac
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] && FileName=$TemporaryName
			fi

			if [[ -n "$Extension" ]]; then
				FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
			else
				FileExtension=$(Get_File_Ext "$Item")
			fi

			FileExtension=${FileExtension,,}
			FileExtension=${FileExtension//\//.}

			if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
				NewName="$FileName.$FileExtension"
			else
				NewName=$FileName
			fi

			TargetPath="${DestinationDir%/}/$NewName"
			[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

			if [[ "$Mode" == "copy" || "$Mode" == "move" ]] && [[ "$Replace" != "yes" ]]; then
				local CollisionIndex=0
				local TargetBase=$FileName
				local TargetExtension=""
				[[ "$NewName" == *.* ]] && TargetExtension=".${NewName##*.}"

				while [[ -e "$TargetPath" ]]; do
					((CollisionIndex += 1))
					NewName="${TargetBase}-(${CollisionIndex})${TargetExtension}"
					TargetPath="${DestinationDir%/}/$NewName"
					[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"
				done
			fi

			Perform_Action "$Item" "$TargetPath" "$AssignedSlot"

			[[ -n "$Pause" ]] && sleep "$Pause"
		) &
	done

	((Current -= 1))
}
