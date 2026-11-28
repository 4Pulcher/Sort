Sanitize() {
	printf "%s" "$1" | tr -d '/\\:*?"<>|' | tr ' ' '_'
}
