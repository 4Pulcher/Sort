Deps_Priv() {
	if [ "$(id -u 2>/dev/null)" = "0" ]; then
		return 0
	elif command -v sudo >/dev/null 2>&1; then
		printf 'sudo'
		return 0
	elif command -v su >/dev/null 2>&1; then
		printf 'su'
		return 0
	fi

	return 1
}
