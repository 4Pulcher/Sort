Get_Image_WxH() {
	local File=$1
	local Resolution

	Resolution=$(
		identify -ping -format '%wx%h\n' -- "$File" 2>/dev/null |
			head -n 1 |
			tr -d '\n\r '
	)

	printf '%s' "${Resolution:-0x0}"
}
