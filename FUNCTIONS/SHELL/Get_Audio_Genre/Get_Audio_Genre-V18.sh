Get_Audio_Genre() {
	local T

	T=$(Id3_Field "$1" genre) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Genre'
}
