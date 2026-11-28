_FF_Run() {
	local Select=$1
	local Entries=$2
	local File=$3
	local Args=()

	[[ -n "$Select" ]] && Args=(-select_streams "$Select")

	timeout 10s ffprobe \
		-v error \
		"${Args[@]}" \
		-show_entries "$Entries" \
		-of default=noprint_wrappers=1:nokey=1 \
		-- "$File" 2>/dev/null
}
