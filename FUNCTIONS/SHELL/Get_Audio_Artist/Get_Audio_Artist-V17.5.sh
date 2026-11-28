Get_Audio_Artist() {
	local T

	T=$(Id3_Field "$1" artist) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Artist'
}
