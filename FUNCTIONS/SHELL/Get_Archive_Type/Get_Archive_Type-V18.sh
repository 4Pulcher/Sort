Get_Archive_Type() {
	local File=$1
	local Hex TarMagic

	[ -f "$File" ] || return 1

	Hex=$(_Comp_Magic "$File" 8) || return 1

	case "$Hex" in
	1f8b*)
		printf 'gzip'
		return 0
		;;
	425a68*)
		printf 'bzip2'
		return 0
		;;
	fd377a585a00*)
		printf 'xz'
		return 0
		;;
	28b52ffd*)
		printf 'zstd'
		return 0
		;;
	504b03* | 504b05* | 504b07*)
		printf 'zip'
		return 0
		;;
	377abcaf271c*)
		printf '7z'
		return 0
		;;
	526172211a07*)
		printf 'rar'
		return 0
		;;
	esac

	# tar: 'ustar' at byte offset 257 (POSIX and GNU)
	TarMagic=$(tail -c +258 -- "$File" 2>/dev/null | head -c 5 | od -An -tx1 | tr -d ' \n')
	if [ "$TarMagic" = '7573746172' ]; then
		printf 'tar'
		return 0
	fi

	return 1
}
