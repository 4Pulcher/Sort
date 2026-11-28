Deps_Has() {
	local Tool=$1

	[ -n "$Tool" ] || return 1
	command -v "$Tool" >/dev/null 2>&1
}
