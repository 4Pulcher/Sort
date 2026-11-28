MIME_Is_Document() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "$MIME" in
	application/pdf | application/postscript | application/rtf | application/msword | application/vnd.ms-excel | application/vnd.ms-powerpoint | application/vnd.openxmlformats-officedocument.* | application/vnd.oasis.opendocument.*) return 0 ;;
	*) return 1 ;;
	esac
}
