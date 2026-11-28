_Exif_Read() {
	local Tag=$1
	local File=$2
	local Value

	if command -v exiftool >/dev/null; then
		Value=$(timeout 10s exiftool -s3 -"$Tag" -- "$File" 2>/dev/null)
	elif command -v identify >/dev/null; then
		Value=$(
			timeout 10s identify -ping -format "%[exif:${Tag}]" -- "$File" 2>/dev/null
		)
	elif declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure exiftool; then
		# exiftool was just installed - retry the read with it.
		Value=$(timeout 10s exiftool -s3 -"$Tag" -- "$File" 2>/dev/null)
	else
		return 127
	fi

	[ -n "$Value" ] || return 1
	printf '%s' "$Value"
}
