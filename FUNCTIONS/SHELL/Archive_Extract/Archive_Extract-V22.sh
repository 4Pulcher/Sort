Archive_Extract() {
	local File=$1 Dest=$2
	local Type Base Out

	File=$(_Comp_Norm "$File")
	Dest=$(_Comp_Norm "$Dest")
	Type=$(Get_Archive_Type "$File") || return 1
	mkdir -p -- "$Dest" || return 1

	case "$Type" in
	tar)
		_Comp_Have tar || return 127
		tar -xaf "$File" -C "$Dest" 2>/dev/null
		;;
	gzip | bzip2 | xz | zstd)
		if _Comp_Is_Tar_Suffix "$File"; then
			_Comp_Have tar || return 127
			tar -xaf "$File" -C "$Dest" 2>/dev/null
			return $?
		fi
		Base=${File##*/}
		case "$Base" in
		*.gz) Out=${Base%.gz} ;;
		*.bz2) Out=${Base%.bz2} ;;
		*.xz) Out=${Base%.xz} ;;
		*.zst | *.zstd) Out=${Base%.zst} ;;
		*) Out="$Base.out" ;;
		esac
		case "$Type" in
		gzip)
			_Comp_Have gunzip || return 127
			gunzip -c -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		bzip2)
			_Comp_Have bunzip2 || return 127
			bunzip2 -c -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		xz)
			_Comp_Have xz || return 127
			xz -dc -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		zstd)
			_Comp_Have zstd || return 127
			zstd -dc -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		esac
		;;
	zip)
		_Comp_Have unzip || return 127
		unzip -o -q -- "$File" -d "$Dest" 2>/dev/null
		;;
	7z)
		_Comp_Have 7z || return 127
		7z x -y -o"$Dest" -- "$File" >/dev/null 2>&1
		;;
	rar)
		_Comp_Have unrar || return 127
		unrar x -y -- "$File" "$Dest/" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}
