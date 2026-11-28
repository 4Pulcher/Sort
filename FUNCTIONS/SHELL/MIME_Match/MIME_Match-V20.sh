MIME_Match() {
	local File=$1
	local Pattern=${2,,}
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "${MIME,,}" in
	$Pattern) return 0 ;;
	*) return 1 ;;
	esac
}
