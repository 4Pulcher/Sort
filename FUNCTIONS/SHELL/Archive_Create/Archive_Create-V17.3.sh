Archive_Create() {
	local Archive
	Archive=$(_Comp_Norm "$1")
	shift
	local Low=${Archive,,}

	[ $# -ge 1 ] || return 1

	case "$Low" in
	*.tar.gz | *.tgz)
		_Comp_Have tar || return 127
		tar -czf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar.bz2)
		_Comp_Have tar || return 127
		tar -cjf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar.xz)
		_Comp_Have tar || return 127
		tar -cJf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar.zst)
		_Comp_Have tar || return 127
		tar --zstd -cf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar)
		_Comp_Have tar || return 127
		tar -cf "$Archive" -- "$@" 2>/dev/null
		;;
	*.zip)
		_Comp_Have zip || return 127
		zip -r -q "$Archive" -- "$@" 2>/dev/null
		;;
	*.7z)
		_Comp_Have 7z || return 127
		7z a -y -- "$Archive" "$@" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}
