Compress_File() {
	local File=$1 Format=$2

	[ -f "$File" ] || return 1

	case "$Format" in
	gzip)
		_Comp_Have gzip || return 127
		gzip -f -- "$File"
		;;
	bzip2)
		_Comp_Have bzip2 || return 127
		bzip2 -f -- "$File"
		;;
	xz)
		_Comp_Have xz || return 127
		xz -f -- "$File"
		;;
	zstd)
		_Comp_Have zstd || return 127
		zstd -f -- "$File"
		;;
	*)
		return 1
		;;
	esac
}
