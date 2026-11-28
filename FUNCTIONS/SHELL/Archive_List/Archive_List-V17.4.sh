Archive_List() {
	local File=$1
	local Type

	File=$(_Comp_Norm "$File")
	Type=$(Get_Archive_Type "$File") || return 1

	case "$Type" in
	tar)
		_Comp_Have tar || return 127
		tar -tf "$File" 2>/dev/null
		;;
	gzip | bzip2 | xz | zstd)
		if _Comp_Is_Tar_Suffix "$File"; then
			_Comp_Have tar || return 127
			tar -tf "$File" 2>/dev/null
			return $?
		fi
		case "$Type" in
		gzip)
			_Comp_Have gzip || return 127
			gzip -l -- "$File" 2>/dev/null | tail -n +2 | awk '{print $4}'
			;;
		bzip2)
			_Comp_Have bzip2 || return 127
			bzip2 -l -- "$File" 2>/dev/null | tail -n +2 | awk '{print $4}'
			;;
		xz)
			_Comp_Have xz || return 127
			xz -l -- "$File" 2>/dev/null | awk '{print $1}' | tail -n +2
			;;
		zstd)
			_Comp_Have zstd || return 127
			zstd -l -- "$File" 2>/dev/null | awk 'NR>2 {print $1}'
			;;
		esac
		;;
	zip)
		_Comp_Have unzip || return 127
		unzip -Z1 -- "$File" 2>/dev/null
		;;
	7z)
		_Comp_Have 7z || return 127
		7z l -y -- "$File" 2>/dev/null | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {print $NF}'
		;;
	rar)
		_Comp_Have unrar || return 127
		unrar lb -- "$File" 2>/dev/null
		;;
	*)
		return 1
		;;
	esac
}
