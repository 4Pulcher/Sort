Get_Audio_Track() {
	local T

	T=$(Id3_Field "$1" track) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Track'
}
