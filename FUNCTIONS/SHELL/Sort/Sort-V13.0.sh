Sort() {
	local Item
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	# Push a new recursion depth frame onto the progress tracking stack
	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		# Increment and display hierarchical progress (e.g., [1]=2/5 ~ [2]=1/10)
		((Counter[$Current] += 1))
		printf 'PROGRESS'
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		# --- Guard 1: Non-existent path ---
		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		# --- Guard 2: Symbolic links (skipped to prevent infinite loops) ---
		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		# --- Guard 3: Directory traversal ---
		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				# Collect directory contents (nullglob handles empty folders safely)
				Children=("$Item"/*)
				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

				# Clean up source folder after moving files if it is now empty
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

		# --- Guard 4: Ignore special devices, sockets, or named pipes ---
		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# ======================================================================
		# REGULAR FILE PROCESSING PIPELINE
		# ======================================================================
		Draw_Line '-'
		printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

		# Step 1: Detect MIME type and split into Category (main) and Subtype
		MIME=$(Get_MIME "$Item")
		MIMEMain=${MIME%%/*}
		MIMESub=${MIME#*/}

		printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

		# Step 2: Apply --type filter if specified by the user
		if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
			printf '%bSKIP:%b MIME type does not match --type=%s\n' \
				"$YELLOW" "$RESET" "$Type"
			Draw_Line '-'
			continue
		fi

		# ----------------------------------------------------------------------
		# Step 3: Construct Destination Directory (--dirs + --subdirs)
		# ----------------------------------------------------------------------
		if [[ -n "$Dirs" ]]; then
			DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
		else
			# Default to the file's current parent directory
			DestinationDir=${Item%/*}
			[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
		fi

		SubDirectory=""
		if [[ -n "$SubDirs" ]]; then
			SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
		fi

		# Combine primary and secondary folders cleanly
		[[ -z "$DestinationDir" ]] && DestinationDir="."
		if [[ -n "$SubDirectory" ]]; then
			DestinationDir="${DestinationDir%/}/$SubDirectory"
		fi

		printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

		# ----------------------------------------------------------------------
		# Step 4: Construct Destination Filename (--rename / --title / --extension)
		# ----------------------------------------------------------------------
		FileName=$(Get_File_Name "$Item")

		# Apply --rename pattern if given
		if [[ -n "$Rename" ]]; then
			TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
			[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
				FileName=$TemporaryName
		fi

		# Apply --title metadata extraction (overrides --rename if successful)
		if [[ "$Title" == "yes" ]]; then
			TemporaryName=""
			case "${MIMEMain,,}" in
			application) TemporaryName=$(Get_Doc_Title "$Item") ;;
			image) TemporaryName=$(Get_Image_Meta "$Item") ;;
			audio) TemporaryName=$(Get_Audio_Info "$Item") ;;
			video) TemporaryName=$(Get_Video_Title "$Item") ;;
			esac

			if [[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]]; then
				FileName=$TemporaryName
			fi
		fi

		# Resolve file extension
		if [[ -n "$Extension" ]]; then
			FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
		else
			FileExtension=$(Get_File_Ext "$Item")
		fi

		# Normalize extension to lowercase and replace MIME slashes with dots
		FileExtension=${FileExtension,,}
		FileExtension=${FileExtension//\//.}

		# Assemble final filename (preserving extensionless files without a trailing dot)
		if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
			NewName="$FileName.$FileExtension"
		else
			NewName=$FileName
		fi

		TargetPath="${DestinationDir%/}/$NewName"
		[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

		# ----------------------------------------------------------------------
		# Step 5: Handle Filename Collisions (when --replace is not active)
		# ----------------------------------------------------------------------
		# Appends -(1), -(2), etc., until a non-conflicting target path is found.
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

		# ----------------------------------------------------------------------
		# Step 6: Execute Action (or Dry-Run Preview) & Optional Pause
		# ----------------------------------------------------------------------
		Perform_Action "$Item" "$TargetPath"

		if [[ -n "$Pause" ]]; then
			sleep "$Pause"
		fi

		Draw_Line '-'
	done

	# Pop the current recursion level off the progress stack
	((Current -= 1))
}
