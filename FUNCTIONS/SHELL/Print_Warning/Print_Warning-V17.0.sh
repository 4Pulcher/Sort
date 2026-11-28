Print_Warning() {
	printf '%sWarning: %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2
	return 0
}
