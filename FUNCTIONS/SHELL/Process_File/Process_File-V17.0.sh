Process_File() {
	local File=$1
	local Mime Main DirPart SubPart NewDir Name Ext New Count=0
	local SourceReal TargetReal

	Status='FAILED'

	[ -f "$File" ] || [ -L "$File" ] || {
		Print_Error "Not a regular file: $File"
		return 1
	}

	# MIME type drives everything; no type -> no destination
	Mime=$(Get_MIME_Type "$File") || {
		Print_Error "No MIME type for: $File"
		return 1
	}
	Main=${Mime%%/*}

	# --type filter: the value must occur in the MIME type
	if [ -n "$Type_Filter" ] && [[ "${Mime,,}" != *"${Type_Filter,,}"* ]]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "Type skip ($Mime): $File"
		return 0
	fi

	# --decompress: archives are extracted first and their contents sorted
	if [ "$Decompress" -eq 1 ] && Archive_Is "$File"; then
		Process_Archive "$File"
		return $?
	fi

	# Primary directory: --dirs= segments, or the MIME type by default
	if [ -n "$Dirs_Spec" ]; then
		DirPart=$(Build_Segments "$Dirs_Spec" "$File" "$Mime" "$Main")
	else
		DirPart="$Mime"
	fi

	# Secondary directory: --subdirs= segments, or per-kind defaults
	if [ -n "$SubDirs_Spec" ]; then
		SubPart=$(Build_Segments "$SubDirs_Spec" "$File" "$Mime" "$Main")
	else
		case "$Main" in
		image)
			local WxH
			WxH=$(Get_Image_WxH "$File") || WxH='unknown'
			SubPart="$(Image_Form "$WxH")/$WxH"

			# With --exif, images with EXIF gain <Camera>/<YYYY-MM-DD> levels
			if [ "$Use_EXIF" -eq 1 ]; then
				local Cam DateDir
				Cam=$(Exif_Camera_Dir "$File") || Cam=''
				DateDir=$(Exif_Date_Dir "$File") || DateDir=''

				local Pre=''
				[ -n "$Cam" ] && Pre="$Cam"
				[ -n "$DateDir" ] && Pre="${Pre:+$Pre/}$DateDir"
				[ -n "$Pre" ] && SubPart="$Pre/$SubPart"

				if [ "$Quiet" -eq 0 ] && [ -n "$Cam$DateDir" ]; then
					Print_Info "EXIF: ${Cam:-unknown camera} ${DateDir:-unknown date}"
				fi
			fi
			;;
		video)
			local WxH Dur
			WxH=$(Get_Media_WxH "$File") || WxH='unknown'
			Dur=$(Video_Duration_Tag "$File") || Dur='unknown'
			SubPart="$WxH/$Dur"
			;;
		*)
			local Unit
			Unit=$(Size_Unit_Name "$File")
			[ "$Unit" = 'Byte' ] || Unit="${Unit}Byte"
			SubPart="$Unit/$(Get_File_Size_Human "$File")"
			;;
		esac
	fi

	NewDir="${Target_Dir#./}/${DirPart:+$DirPart/}$SubPart"
	NewDir=${NewDir#./}

	# New name and extension
	Name=$(Build_Name "$File" "$Mime" "$Main") || {
		Print_Error "Cannot build a name for: $File"
		return 1
	}
	Ext=$(Build_Extension "$File" "$Mime")

	mkdir -p -- "$NewDir" || {
		Print_Error "Cannot create: $NewDir"
		return 1
	}
	New="$NewDir/$Name$Ext"

	# Without --replace, never clobber: slide a ~(N) counter in.
	# Destructive modes act on the calculated target as-is, no counter.
	if [ ! "$Replace" = 'Yes' ]; then
		case "$Modus" in
		Remove | Trash | Shred) ;;
		*)
			while [ -e "$New" ]; do
				Count=$((Count + 1))
				New="$NewDir/$Name~($Count)$Ext"
			done
			;;
		esac
	fi

	# Already in place -> nothing to do
	SourceReal=$(realpath -- "$File" 2>/dev/null)
	TargetReal=$(realpath -m -- "$New" 2>/dev/null)
	if [ -n "$SourceReal" ] && [ "$SourceReal" = "$TargetReal" ]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "Same place: $File"
		return 0
	fi

	# Act according to the mode
	case "$Modus" in
	Copy)
		if cp -v -- "$File" "$New"; then
			Status='COPIED'
			Print_Ok "$File -> $New"
			Log_Action "COPY $File -> $New"
			Undo_Action "rm -f -- '$(printf "%s" "$New" | sed "s/'/'\\\\''/g")'"
			[ "$Strip" -eq 1 ] && Strip_Target "$New"
		else
			Print_Error "Copy failed: $File"
			return 1
		fi
		;;
	Move)
		if mv -v -- "$File" "$New"; then
			Status='MOVED'
			Print_Ok "$File -> $New"
			Log_Action "MOVE $File -> $New"
			Undo_Action "mv -f -- '$(printf "%s" "$New" | sed "s/'/'\\\\''/g")' '$(printf "%s" "$File" | sed "s/'/'\\\\''/g")'"
			[ "$Strip" -eq 1 ] && Strip_Target "$New"
		else
			Print_Error "Move failed: $File"
			return 1
		fi
		;;
	Remove)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "Remove: target not found: $New"
			return 1
		fi
		if rm -v -- "$New"; then
			Status='REMOVED'
			Print_Ok "Removed: $New"
			Log_Action "REMOVE $New"
		else
			Print_Error "Remove failed: $New"
			return 1
		fi
		;;
	Trash)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "Trash: target not found: $New"
			return 1
		fi
		Deps_Ensure trash-put || {
			Print_Error 'Trash needs trash-put (trash-cli)'
			return 1
		}
		if trash-put -- "$New"; then
			Status='TRASHED'
			Print_Ok "Trashed: $New"
			Log_Action "TRASH $New"
		else
			Print_Error "Trash failed: $New"
			return 1
		fi
		;;
	Shred)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "Shred: target not found: $New"
			return 1
		fi
		if shred -u -n 1 -- "$New"; then
			Status='SHREDDED'
			Print_Ok "Shredded: $New"
			Log_Action "SHRED $New"
		else
			Print_Error "Shred failed: $New"
			return 1
		fi
		;;
	*)
		Status='PREVIEW'
		Print_Message "$File <=> $New"
		;;
	esac

	# Optional pause after each file
	[ "$Pause" -gt 0 ] 2>/dev/null && sleep "$Pause"

	return 0
}
