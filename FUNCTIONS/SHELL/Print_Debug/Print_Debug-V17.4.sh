Print_Debug() {
	[ "${DEBUG:-0}" = "1" ] || return 0
	printf '%s[DEBUG]%s %s\n' "$C_MAGENTA" "$C_RESET" "$*" >&2
	return 0
}
