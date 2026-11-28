Deps_Init() {
	local Spec Tool Package
	local Missing=()
	local Packages=()

	[ $# -gt 0 ] && [ -n "${1:-}" ] || return 0

	for Spec in "$@"; do
		Tool=${Spec%%:*}
		Package=${Spec#*:}
		[ "$Package" != "$Spec" ] || Package=""

		if Deps_Has "$Tool"; then
			continue
		fi

		Missing+=("$Tool")

		if [ -z "$Package" ]; then
			Package=$(Deps_Package "$Tool") || Package=""
		fi

		[ -n "$Package" ] && Packages+=("$Package")
	done

	[ ${#Missing[@]} -gt 0 ] || return 0

	printf 'deps: missing: %s\n' "${Missing[*]}" >&2

	[ ${#Packages[@]} -gt 0 ] || return 1

	# One single install proposal for everything that is missing.
	_Deps_Propose_Install "${Packages[@]}" || return 1

	# True only if every requested tool is usable now.
	Deps_Missing "${Missing[@]}" >/dev/null
}
