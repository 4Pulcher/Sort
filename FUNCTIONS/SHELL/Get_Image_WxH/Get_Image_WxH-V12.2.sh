Get_Image_WxH() {
	local Resolution
	Resolution=$(identify -ping -format '%wx%h\n' -- "$1" 2>/dev/null | head -n 1 | tr -d '\r\n ')
	printf '%s' "${Resolution:-0x0}"
}
