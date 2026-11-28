Sort() {
	local Item
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		((Counter[$Current] += 1))
		local ProgStr="PROGRESS"
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			ProgStr+=" ~ [$Level]=${Counter[$Level]}/${Total[$Level]}"
		done
		# Quick syntax correction for loop string
		# (rebuilding clean prog output)
		ProgStr="PROGRESS"
		for ((Level = 1; Level <= Current; Level++)); do
			ProgStr+=" ~ [$Level]=${Counter[$Level]}/${Total[$Level]}"
		done
		Log_Print '%s\n' "$ProgStr"

		[[ ! -e "$Item" && ! -L "$Item" ]] && {
			Log_Print 'SKIP: Does not exist: %s\n' "$Item"
			continue
		}
		[[ -L "$Item" ]] && {
			Log_Print 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		}

		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				Log_Print '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'
				Children=("$Item"/*)
				((${#Children[@]} > 0)) && Sort "${Children[@]}"
				Draw_Line '<'
				[[ "$Mode" == "move" ]] && rmdir -v -- "$Item" 2>&1
			else
				Log_Print '%bDIR:%b Skipping (use --recursive): %s\n' "$YELLOW" "$RESET" "$Item"
			fi
			Draw_Line '='
			continue
		fi

		[[ ! -f "$Item" ]] && {
			Log_Print 'SKIP: Not regular file: %s\n' "$Item"
			continue
		}

		(
			Draw_Line '-'
			Log_Print '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

			MIME=$(Get_MIME "$Item")
			MIMEMain=${MIME%%/*}
			MIMESub=${MIME#*/}

			Log_Print '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

			if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
				Log_Print '%bSKIP:%b MIME does not match type=%s\n' "$YELLOW" "$RESET" "$Type"
				Draw_Line '-'
				exit 0
			fi

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

			Log_Print '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

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

			Log_Print '%bNEW NAME:%b %s\n' "$YELLOW" "$RESET" "$NewName"
			Log_Print '%bTARGET:%b %s\n' "$YELLOW" "$RESET" "$TargetPath"

			Perform_Action "$Item" "$TargetPath"
			[[ -n "$Pause" ]] && sleep "$Pause"
			Draw_Line '-'
		) &

		if ((MAX_JOBS > 1)); then
			while (($(jobs -r | wc -l) >= MAX_JOBS)); do
				sleep 0.1
			done
		fi
	done

	((Current -= 1))
}
