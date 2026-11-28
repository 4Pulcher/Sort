EXIF_Strip() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1

	if command -v exiftool >/dev/null; then
		timeout 60s exiftool -all= -o "$Out" -- "$In" >/dev/null 2>&1
	elif command -v magick >/dev/null; then
		timeout 120s magick "$In" -strip "$Out" >/dev/null 2>&1
	elif command -v convert >/dev/null; then
		timeout 120s convert "$In" -strip "$Out" >/dev/null 2>&1
	else
		return 127
	fi
}
