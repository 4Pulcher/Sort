Get_Image_Meta() {
	local File=$1
	local Date

	# 1. Try ExifTool common date tags (DateTimeOriginal, CreateDate, ModifyDate)
	Date=$(Get_Exif_Tag "$File" DateTimeOriginal)
	[[ -z "$Date" ]] && Date=$(Get_Exif_Tag "$File" CreateDate)
	[[ -z "$Date" ]] && Date=$(Get_Exif_Tag "$File" ModifyDate)

	# 2. Fall back to ffprobe if ExifTool returned nothing
	if [[ -z "$Date" ]]; then
		Date=$(
			timeout 5s ffprobe -v error \
				-show_entries format_tags=date_time_original \
				-of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null
		)
	fi

	# 3. Final fallback to filesystem creation time
	[[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$File")

	# Sanitize characters unsafe for filenames
	printf '%s' "${Date:-ERROR}" | tr -d '/\\:*?"<>|'
}
