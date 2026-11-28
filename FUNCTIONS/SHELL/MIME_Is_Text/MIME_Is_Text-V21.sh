MIME_Is_Text() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	[[ "${MIME%%/*}" == "text" ]]
}
