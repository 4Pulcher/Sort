Get_MIME_Best_Extension() {
	local File=$1
	local Mime Sub Variant OwnExt Ext Main Base

	Mime=$(Get_MIME_Type "$File") || return $?
	Mime=${Mime%%;*}
	Mime=${Mime,,}

	# 1) exact entry in the type -> extension table
	Ext=$(_MIME_Lookup_Ext "$Mime") && [ -n "$Ext" ] && {
		printf '%s' "$Ext"
		return 0
	}

	# 2) x- normalized variants of the subtype
	Sub=${Mime#*/}
	case "$Sub" in
	x-*)
		Variant="${Mime%%/*}/${Sub#x-}"
		Ext=$(_MIME_Lookup_Ext "$Variant") && [ -n "$Ext" ] && {
			printf '%s' "$Ext"
			return 0
		}
		;;
	*)
		Variant="${Mime%%/*}/x-${Sub}"
		Ext=$(_MIME_Lookup_Ext "$Variant") && [ -n "$Ext" ] && {
			printf '%s' "$Ext"
			return 0
		}
		;;
	esac

	# The file's own extension (same semantics as Get_File_Ext, kept inline
	# so this module stays standalone)
	Base=${File##*/}
	case "$Base" in
	.*.* | *.*.*) OwnExt=${Base##*.} ;;
	*) OwnExt='' ;;
	esac
	OwnExt=${OwnExt,,}

	# 3) the own extension, when it already maps to the detected type
	if [ -n "$OwnExt" ]; then
		Ext=$(Get_Extension_MIME "$OwnExt") || Ext=''
		if [ "$Ext" = "$Mime" ]; then
			printf '%s' "$OwnExt"
			return 0
		fi
	fi

	# 4) main-type default - only for files without any extension
	if [ -z "$OwnExt" ]; then
		Main=${Mime%%/*}
		case "$Main" in
		text)
			printf 'txt'
			return 0
			;;
		image)
			printf 'img'
			return 0
			;;
		audio)
			printf 'mp3'
			return 0
			;;
		video)
			printf 'mp4'
			return 0
			;;
		application)
			printf 'bin'
			return 0
			;;
		esac
	fi

	# 5) keep the original extension as the last resort
	if [ -n "$OwnExt" ]; then
		printf '%s' "$OwnExt"
		return 0
	fi

	return 1
}
