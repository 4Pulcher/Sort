Print_Log() {
	local Stamp

	Stamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
	printf '%s[%s]%s %s\n' "$C_DIM" "$Stamp" "$C_RESET" "$*" >&2
	return 0
}
