Main() {
	local Rc

	# No arguments at all: show the short usage
	if [ $# -eq 0 ]; then
		Usage
		return 0
	fi

	Parse_Arguments "$@"

	# The --title sugar doubles as --rename=title when no rename was given
	Validate_Options || return 1

	# --magic (V17.5): magic-number detection report, then exit
	if [ "${Magic_Mode:-0}" -eq 1 ]; then
		Collect_Files
		if [ "${#Targets[@]}" -eq 0 ]; then
			Print_Warning 'Nothing to inspect.'
			return 1
		fi
		if [ "$Quiet" -eq 0 ]; then
			Draw_Line '='
			Print_Header "Magic-number report (${#Targets[@]} file(s))"
			Draw_Line '='
		fi
		Magic_Report_All
		return 0
	fi

	# --scan-raw (V20): raw device signature scan, then exit
	if [ -n "$Raw_Device" ]; then
		Raw_Scan_Main "$Raw_Device" "$Modus" "$Target_Dir" "$LogFile"
		return $?
	fi

	# --scan (V21): partition + per-partition signature scan, then exit
	if [ -n "$Fs_Formats_Arg" ]; then
		if [ ${#Files[@]} -eq 0 ]; then
			Print_Error "$(T 'SCAN: --scan needs a device or image path')"
			return 64
		fi
		Fs_Scan_Main "${Files[0]}" "$Fs_Formats_Arg" "$Modus" "$Target_Dir" "$LogFile"
		return $?
	fi

	# Init-system: one batch install proposal for the optional tools
	# (exiftool joins when EXIF or metadata-title features are requested)
	if [ "$Quiet" -eq 0 ]; then
		if [ "$Use_EXIF" -eq 1 ] || [ "$Strip" -eq 1 ] || [ "$Title_Mode" -eq 1 ] || [ "$Rename" = 'title' ] || [ -n "$UndoFile" ]; then
			Deps_Init identify ffprobe exiftool || true
		else
			Deps_Init identify ffprobe || true
		fi
		if [ "$Decompress" -eq 1 ]; then
			Deps_Init tar gzip unzip zip bzip2 xz zstd 7z unrar || true
		fi
	fi

	Prepare_Optional_Output

	# The array of files to treat, built before any work starts
	Collect_Files

	if [ "${#Targets[@]}" -eq 0 ]; then
		Print_Warning 'Nothing to treat.'
		return 1
	fi

	if [ "$Quiet" -eq 0 ]; then
		Draw_Line '='
		Print_Header "$(Tf 'Sorting %s file(s) - mode: %s, jobs: %s' "${#Targets[@]}" "$Modus" "$Max_Jobs")"
	fi

	Run_Threads "${Targets[@]}"
	Rc=$?

	# Make the undo script executable when one was written
	[ -n "$UndoFile" ] && [ -f "$UndoFile" ] && chmod +x -- "$UndoFile"

	return $Rc
}
