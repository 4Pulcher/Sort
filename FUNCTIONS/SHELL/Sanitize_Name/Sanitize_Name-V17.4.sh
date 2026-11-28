Sanitize_Name() {
	local String=${1// /_}

	printf '%s' "$String" | tr -d '/\\:*?"<>|'
}
