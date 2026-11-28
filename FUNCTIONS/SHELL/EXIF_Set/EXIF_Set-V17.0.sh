EXIF_Set() {
	local Tag=$1
	local Value=$2
	local File=$3

	[ -n "$Tag" ] && [ -n "$Value" ] && [ -f "$File" ] || return 1
	_Exif_Have exiftool || return 127

	timeout 60s exiftool -overwrite_original "-$Tag=$Value" -- "$File" >/dev/null 2>&1
}
