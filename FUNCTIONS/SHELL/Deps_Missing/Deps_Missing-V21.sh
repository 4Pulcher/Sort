Deps_Missing() {
	local Tool
	local Out=""

	[ $# -gt 0 ] || return 0

	for Tool in "$@"; do
		Deps_Has "$Tool" || Out="$Out $Tool"
	done

	[ -z "$Out" ] && return 0
	printf '%s\n' "${Out# }"
	return 1
}
