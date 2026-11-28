MIME_Is_Archive() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "$MIME" in
	application/zip | application/gzip | application/x-gzip | application/x-bzip2 | application/x-xz | application/x-7z-compressed | application/vnd.rar | application/x-tar | application/x-iso9660-image | application/x-cpio | application/x-archive) return 0 ;;
	*) return 1 ;;
	esac
}
