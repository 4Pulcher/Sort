Get_Media_WxH() {
	local Resolution
	Resolution=$(Get_Exif_Tag "$1" ImageSize)
	[[ -z "$Resolution" ]] && Resolution=$(
		timeout 10s ffprobe -v error -select_streams v:0 \
			-show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null
	)
	Resolution=${Resolution%x}
	Resolution=${Resolution// /x}
	printf '%s' "${Resolution:-0x0}"
}
