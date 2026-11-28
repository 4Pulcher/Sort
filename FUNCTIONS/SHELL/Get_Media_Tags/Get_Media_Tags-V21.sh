Get_Media_Tags() {
	local File=$1
	local Tags

	_FF_Have ffprobe || return 127

	Tags=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries format_tags \
			-of default=noprint_wrappers=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Tags" ] || return 1
	printf '%s\n' "$Tags"
}
