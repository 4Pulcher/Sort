Get_Media_WxH() {
	local File=$1
	local Resolution

	# First use without ffprobe: propose the install, then fall back to 0x0.
	command -v ffprobe >/dev/null 2>&1 ||
		{ declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure ffprobe; }

	Resolution=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams v:0 \
			-show_entries stream=width,height \
			-of csv=s=x:p=0 \
			"$File" 2>/dev/null
	)

	# ffprobe can append a trailing "x" when one dimension is missing.
	Resolution=${Resolution%x}

	printf '%s' "${Resolution:-0x0}"
}
