Get_Image_WxH() {
	local File=$1
	local Resolution

	# First use without ImageMagick: propose the install, then fall back to 0x0.
	command -v identify >/dev/null || command -v magick >/dev/null || {
		declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure identify
	}

	Resolution=$(
		identify -ping -format '%wx%h\n' -- "$File" 2>/dev/null |
			head -n 1 |
			tr -d '\r\n '
	)

	printf '%s' "${Resolution:-0x0}"
}
