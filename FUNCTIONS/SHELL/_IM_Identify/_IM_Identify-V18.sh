_IM_Identify() {
	local Format=$1
	local File=$2
	local Out

	if command -v identify >/dev/null; then
		Out=$(timeout 10s identify -ping -format "$Format" -- "$File" 2>/dev/null)
	elif command -v magick >/dev/null; then
		Out=$(timeout 10s magick identify -ping -format "$Format" -- "$File" 2>/dev/null)
	elif declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure identify; then
		# ImageMagick was just installed - retry the read.
		Out=$(timeout 10s identify -ping -format "$Format" -- "$File" 2>/dev/null)
	else
		return 127
	fi

	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}
