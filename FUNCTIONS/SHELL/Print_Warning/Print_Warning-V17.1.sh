Print_Warning() {
	printf '%s%s%s%s\n' "$C_YELLOW" "$(T 'Warning: ')" "$*" "$C_RESET" >&2
	return 0
}
