Get_Media_Info() {
	local File=$1 Out W H WxH Dur

	# First use without ffprobe: propose the install, then fall back.
	command -v ffprobe >/dev/null 2>&1 ||
		{ declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure ffprobe; }

	Out=$(timeout 10s ffprobe \
		-v error \
		-select_streams v:0 \
		-show_entries stream=width,height:format=duration \
		-of default=noprint_wrappers=1:nokey=1 \
		-- "$File" 2>/dev/null) || {
		printf '0x0|unknown'
		return 1
	}

	# Lines: width, height, duration - flatten and read them back
	Out=${Out//$'\n'/ }
	read -r W H Dur <<<"$Out"

	if [[ "$W" =~ ^[0-9]+$ ]] && [[ "$H" =~ ^[0-9]+$ ]]; then
		WxH="${W}x${H}"
	else
		WxH='0x0'
	fi

	[[ "$Dur" =~ ^[0-9]+([.][0-9]+)?$ ]] || Dur=''
	[ -n "$Dur" ] && Dur=$(Duration_Tag_From_Seconds "$Dur") || Dur='unknown'

	printf '%s|%s' "$WxH" "$Dur"
}
