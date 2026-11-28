Print_Error() {
	printf '%s%s%s%s\n' "$C_RED" "$(T 'Error: ')" "$*" "$C_RESET" >&2
	return 1
}
