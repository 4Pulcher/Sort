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

		printf 'PROGRESS'

		local Level

		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				Children=("$Item"/*)
				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

				if [[ "$Mode" == "move" ]]; then
					rmdir -v -- "$Item" 2>&1
				fi
			else
				printf '%bDIR:%b Skipping (use --recursive): %s\n' \
					"$YELLOW" "$RESET" "$Item"
			fi
			Draw_Line '='
			continue
		fi

		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# ----------------------------------------------------------------------
		# MULTI-THREADED FILE EXECUTION BLOCK (Spawned in background if MAX_JOBS > 1)
		# ----------------------------------------------------------------------
		(
			Draw_Line '-'
			printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

			MIME=$(Get_MIME "$Item")
			MIMEMain=${MIME%%/*}
			MIMESub=${MIME#*/}

			printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

			if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
				printf '%bSKIP:%b MIME type does not match --type=%s\n' \
					"$YELLOW" "$RESET" "$Type"
				Draw_Line '-'
				exit 0
			fi

			# Step 1: Destination Directory
			if [[ -n "$Dirs" ]]; then
				DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
			else
				DestinationDir=${Item%/*}
				[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
			fi

			SubDirectory=""
			if [[ -n "$SubDirs" ]]; then
				SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
			fi

			[[ -z "$DestinationDir" ]] && DestinationDir="."
			if [[ -n "$SubDirectory" ]]; then
				DestinationDir="${DestinationDir%/}/$SubDirectory"
			fi

			printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

			# Step 2: Filename
			FileName=$(Get_File_Name "$Item")
			if [[ -n "$Rename" ]]; then
				TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
					FileName=$TemporaryName
			fi

			if [[ "$Title" == "yes" ]]; then
				TemporaryName=""
				case "${MIMEMain,,}" in
				application) TemporaryName=$(Get_Doc_Title "$Item") ;;
				image) TemporaryName=$(Get_Image_Meta "$Item") ;;
				audio) TemporaryName=$(Get_Audio_Info "$Item") ;;
				video) TemporaryName=$(Get_Video_Title "$Item") ;;
				esac
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
					FileName=$TemporaryName
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

			# Step 3: Collision Management
			if [[ "$Mode" == "copy" || "$Mode" == "move" ]] && [[ "$Replace" != "yes" ]]; then
				local CollisionIndex=0
				local TargetBase=$FileName
				local TargetExtension=""

				if [[ "$NewName" == *.* ]]; then
					TargetExtension=".${NewName##*.}"
				fi

				while [[ -e "$TargetPath" ]]; do
					((CollisionIndex += 1))
					NewName="${TargetBase}-(${CollisionIndex})${TargetExtension}"
					TargetPath="${DestinationDir%/}/$NewName"
					[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"
				done
			fi

			printf '%bNEW NAME:%b %s\n' "$YELLOW" "$RESET" "$NewName"
			printf '%bTARGET:%b %s\n' "$YELLOW" "$RESET" "$TargetPath"

			# Step 4: Perform Action
			Perform_Action "$Item" "$TargetPath"

			if [[ -n "$Pause" ]]; then
				sleep "$Pause"
			fi

			Draw_Line '-'
		) &

		# --- CONCURRENCY THROTTLE ---
		# If MAX_JOBS > 1, wait until active background job count drops below MAX_JOBS
		if ((MAX_JOBS > 1)); then
			while (($(jobs -r | wc -l) >= MAX_JOBS)); do
				sleep 0.1
			done
		fi
	done

	((Current -= 1))
}
