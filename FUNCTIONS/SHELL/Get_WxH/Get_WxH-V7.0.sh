Get_WxH() {
	timeout 10s ffprobe -v error \
		-select_streams v:0 \
		-show_entries stream=width,height \
		-of csv=s=x:p=0 "$1" 2>/dev/null || printf "0x0"
}
