EXIF_Copy() {
	local Src=$1
	local Dst=$2

	[ -f "$Src" ] && [ -f "$Dst" ] || return 1
	_Exif_Have exiftool || return 127

	timeout 60s exiftool -overwrite_original -tagsfromfile "$Src" -exif:all -- "$Dst" >/dev/null 2>&1
}
