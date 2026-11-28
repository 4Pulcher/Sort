Archive_Test() {
	local File=$1
	local Type

	File=$(_Comp_Norm "$File")
	Type=$(Get_Archive_Type "$File") || return 1

	case "$Type" in
	tar)
		_Comp_Have tar || return 127
		tar -tf "$File" >/dev/null 2>&1
		;;
	gzip | bzip2 | xz | zstd)
		if _Comp_Is_Tar_Suffix "$File"; then
			_Comp_Have tar || return 127
			tar -tf "$File" >/dev/null 2>&1
			return $?
		fi
		case "$Type" in
		gzip)
			_Comp_Have gzip || return 127
			gzip -t -- "$File" 2>/dev/null
			;;
		bzip2)
			_Comp_Have bzip2 || return 127
			bzip2 -t -- "$File" 2>/dev/null
			;;
		xz)
			_Comp_Have xz || return 127
			xz -t -- "$File" 2>/dev/null
			;;
		zstd)
			_Comp_Have zstd || return 127
			zstd -t -- "$File" 2>/dev/null
			;;
		esac
		;;
	zip)
		_Comp_Have unzip || return 127
		unzip -t -qq -- "$File" >/dev/null 2>&1
		;;
	7z)
		_Comp_Have 7z || return 127
		7z t -y -- "$File" >/dev/null 2>&1
		;;
	rar)
		_Comp_Have unrar || return 127
		unrar t -y -- "$File" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}
