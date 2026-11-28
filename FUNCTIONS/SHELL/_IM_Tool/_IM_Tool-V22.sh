_IM_Tool() {
	if command -v magick >/dev/null; then
		timeout 120s magick "$@" 2>/dev/null
	elif command -v convert >/dev/null; then
		timeout 120s convert "$@" 2>/dev/null
	elif declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure magick; then
		# ImageMagick was just installed - retry the action.
		timeout 120s magick "$@" 2>/dev/null
	else
		return 127
	fi
}
