Get_Image_Meta() {
	local File=$1
	local Date

	[ -f "$File" ] || return 1

	Date=$(_IM_Identify '%[exif:DateTimeOriginal]' "$File" 2>/dev/null)

	if [ -z "$Date" ] && command -v ffprobe >/dev/null; then
		Date=$(
			timeout 5s ffprobe \
				-v error \
				-show_entries format_tags=date_time_original \
				-of default=noprint_wrappers=1:nokey=1 \
				-- "$File" 2>/dev/null
		)
	fi

	if [ -z "$Date" ] && command -v stat >/dev/null; then
		Date=$(stat -c '%w' -- "$File" 2>/dev/null)
		[ "$Date" = "-" ] && Date=''
	fi

	[ -n "$Date" ] || return 1
	printf '%s' "$Date"
}
