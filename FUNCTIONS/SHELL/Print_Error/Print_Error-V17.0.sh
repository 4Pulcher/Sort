Print_Error() {
	printf '%sError: %s%s\n' "$C_RED" "$*" "$C_RESET" >&2
	return 1
}
