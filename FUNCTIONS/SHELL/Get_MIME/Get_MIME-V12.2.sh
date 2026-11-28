Get_MIME() {
	local File=$1
	local MIME
	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	printf '%s' "${MIME:-ERROR}"
}
