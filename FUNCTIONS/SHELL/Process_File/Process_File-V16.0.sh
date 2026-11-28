Process_File() {
	local File=$1
	local Mime Main Sub Name Ext NewDir New Count=0

	Status='FAILED'

	[ -f "$File" ] || {
		Print_Error "Not a regular file: $File"
		return 1
	}

	# MIME type drives everything; no type -> no destination
	Mime=$(Get_MIME_Type "$File") || {
		Print_Error "No MIME type for: $File"
		return 1
	}
	Main=${Mime%%/*}

	# Sub-path per kind: images by shape, videos by geometry+length, rest by size
	case "$Main" in
	image)
		local WxH
		WxH=$(Get_Image_WxH "$File") || WxH='unknown'
		Sub="$(Image_Form "$WxH")/$WxH"
		;;
	video)
		local WxH Dur
		WxH=$(Get_Media_WxH "$File") || WxH='unknown'
		Dur=$(Video_Duration_Tag "$File") || Dur='unknown'
		Sub="$WxH/$Dur"
		;;
	*)
		Sub="$(File_Size_Category "$File")/$(Get_File_Size_Human "$File")"
		;;
	esac

	NewDir="$Mime/$Sub"

	# New name and extension
	Name=$(Build_Name "$File") || {
		Print_Error "Cannot build a name for: $File"
		return 1
	}
	Ext=$(Build_Extension "$File" "$Mime")

	mkdir -p -- "$NewDir" || {
		Print_Error "Cannot create: $NewDir"
		return 1
	}
	New="$NewDir/$Name$Ext"

	# Without --replace, never clobber: slide a ~(N) counter in
	if [ ! "$Replace" = 'Yes' ]; then
		while [ -e "$New" ]; do
			Count=$((Count + 1))
			New="$NewDir/$Name~($Count)$Ext"
		done
	fi

	# Already in place -> nothing to do
	if [ "${File#./}" = "$New" ]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "Same place: $File"
		return 0
	fi

	case "$Modus" in
	Copy)
		if cp -v -- "$File" "$New"; then
			Status='COPIED'
			Print_Ok "$File -> $New"
		else
			Print_Error "Copy failed: $File"
			return 1
		fi
		;;
	Move)
		if mv -v -- "$File" "$New"; then
			Status='MOVED'
			Print_Ok "$File -> $New"
		else
			Print_Error "Move failed: $File"
			return 1
		fi
		;;
	*)
		Status='PREVIEW'
		Print_Message "$File <=> $New"
		;;
	esac
}
