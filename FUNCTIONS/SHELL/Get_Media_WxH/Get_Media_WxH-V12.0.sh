Get_Media_WxH() {
	local File=$1
	local Resolution

	Resolution=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams v:0 \
			-show_entries stream=width,height \
			-of csv=s=x:p=0 \
			"$File" 2>/dev/null
	)
	Resolution=${Resolution%x}
	printf '%s' "${Resolution:-0x0}"
}
