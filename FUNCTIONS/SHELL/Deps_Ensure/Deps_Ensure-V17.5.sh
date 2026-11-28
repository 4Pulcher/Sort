Deps_Ensure() {
	local Tool=$1
	local Package=${2:-}

	Deps_Has "$Tool" && return 0

	[ -n "$Package" ] || Package=$(Deps_Package "$Tool") || {
		printf '%s\n' "$(Tf "deps: '%s' is missing and its package name is unknown" "$Tool")" >&2
		return 1
	}

	_Deps_Propose_Install "$Package" || return 1

	# True only if the tool is usable after the install.
	Deps_Has "$Tool"
}
