Get_Image_Meta() {
	local File=$1
	local Date

	Date=$(
		timeout 5s ffprobe \
			-v error \
			-show_entries format_tags=date_time_original \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	[[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$File")

	printf '%s' "${Date:-ERROR}"
}
