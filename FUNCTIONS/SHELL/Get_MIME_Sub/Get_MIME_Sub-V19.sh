Get_MIME_Sub() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	printf '%s' "${MIME#*/}"
}
