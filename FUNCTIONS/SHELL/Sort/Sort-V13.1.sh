Sort() {
	local Item
	local Directory
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	# Increase recursion depth and initialize this level's progress counters.
	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		# Update progress for the current recursion level.
		((Counter[$Current] += 1))
		printf 'PROGRESS'
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		# Skip paths that do not exist, including broken symbolic links.
		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		# Symbolic links are deliberately skipped to avoid following links
		# outside the requested directory tree or processing the same target twice.
		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		# Directory handling: recurse only when the user supplied --recursive.
		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				# Expand the directory's contents, including hidden files.
				# nullglob ensures an empty directory produces an empty array.
				Children=("$Item"/*)

				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

				# After a move operation, remove the source directory only if
				# it is now empty. rmdir safely refuses non-empty directories.
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

		# Ignore special filesystem objects; this organizer handles regular files.
		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# Start processing a regular file.
		Draw_Line '-'
		printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

		# Read MIME information once and split it into major and minor parts.
		MIME=$(Get_MIME "$Item")
		MIMEMain=${MIME%%/*}
		MIMESub=${MIME#*/}

		printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

		# If --type was provided, the requested text must occur in the MIME type.
		if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
			printf '%bSKIP:%b MIME type does not match --type=%s\n' \
				"$YELLOW" "$RESET" "$Type"
			Draw_Line '-'
			continue
		fi

		# --------------------------------------------------------------------
		# 10a. Build the destination directory
		# --------------------------------------------------------------------

		# --dirs selects the primary directory component. Without it, use the
		# source file's current parent directory.
		if [[ -n "$Dirs" ]]; then
			DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
		else
			DestinationDir=${Item%/*}
			[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
		fi

		# --subdirs adds one more level beneath the primary directory.
		SubDirectory=""
		if [[ -n "$SubDirs" ]]; then
			SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
		fi

		# Assemble the final destination directory, avoiding empty components.
		if [[ -z "$DestinationDir" ]]; then
			DestinationDir="."
		fi
		if [[ -n "$SubDirectory" ]]; then
			DestinationDir="${DestinationDir%/}/$SubDirectory"
		fi

		printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

		# --------------------------------------------------------------------
		# 10b. Build the destination filename
		# --------------------------------------------------------------------

		# Start with the original basename; --rename can replace it with a
		# dynamic value such as sha256sum, year or random.
		FileName=$(Get_File_Name "$Item")
		if [[ -n "$Rename" ]]; then
			TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
			[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
				FileName=$TemporaryName
		fi

		# --title takes precedence over --rename when metadata is available.
		if [[ "$Title" == "yes" ]]; then
			TemporaryName=""
			case "${MIMEMain,,}" in
			application)
				TemporaryName=$(Get_Doc_Title "$Item")
				;;
			image)
				TemporaryName=$(Get_Image_Meta "$Item")
				;;
			audio)
				TemporaryName=$(Get_Audio_Info "$Item")
				;;
			video)
				TemporaryName=$(Get_Video_Title "$Item")
				;;
			esac

			# Do not replace the filename with an empty or error result.
			if [[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]]; then
				FileName=$TemporaryName
			fi
		fi

		# Use the original extension unless --extension supplied a replacement.
		if [[ -n "$Extension" ]]; then
			FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
		else
			FileExtension=$(Get_File_Ext "$Item")
		fi

		# Normalize the extension and replace a MIME slash with a dot.
		FileExtension=${FileExtension,,}
		FileExtension=${FileExtension//\//.}

		# Assemble the destination filename. A file with no extension is kept
		# extensionless instead of receiving an artificial trailing dot.
		if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
			NewName="$FileName.$FileExtension"
		else
			NewName=$FileName
		fi

		TargetPath="${DestinationDir%/}/$NewName"
		[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

		# --------------------------------------------------------------------
		# 10c. Avoid accidental name collisions for copy/move
		# --------------------------------------------------------------------

		# When --replace is absent, find the first unused "name-(N).ext".
		# This check applies only to copy and move, not destructive modes.
		if [[ "$Mode" == "copy" || "$Mode" == "move" ]] &&
			[[ "$Replace" != "yes" ]]; then
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

		# --------------------------------------------------------------------
		# 10d. Perform the requested action, or show a dry-run preview
		# --------------------------------------------------------------------

		Perform_Action "$Item" "$TargetPath"

		# Optional pause between files, useful when watching terminal output.
		if [[ -n "$Pause" ]]; then
			sleep "$Pause"
		fi

		Draw_Line '-'
	done

	# Decrease the recursion depth when this directory level has completed.
	((Current -= 1))
}
