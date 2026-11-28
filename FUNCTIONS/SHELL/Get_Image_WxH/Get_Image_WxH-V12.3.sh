Get_Image_WxH() {
	local Resolution
	# ExifTool preferred for image dimensions, ImageMagick fallback
	Resolution=$(Get_Exif_Tag "$1" ImageSize)
	[[ -z "$Resolution" ]] && Resolution=$(identify -ping -format '%wx%h\n' -- "$1" 2>/dev/null | head -n 1 | tr -d '\r\n ')
	Resolution=${Resolution// /x}
	printf '%s' "${Resolution:-0x0}"
}
