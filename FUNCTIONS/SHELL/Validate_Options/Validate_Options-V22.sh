Validate_Options() {
	case " $LANG_CODES " in
	*" $Lang "*)
		;;
	*)
		Print_Error "$(Tf 'Unsupported language: %s (see --lang)' "$Lang")"
		Lang_List >&2
		return 1
		;;
	esac

	case "$Modus" in
	Print | Copy | Move | Remove | Trash | Shred) ;;
	*)
		Print_Error "$(Tf 'Unsupported mode: %s' "$Modus")"
		return 1
		;;
	esac

	if [ -n "$Pause" ] && ! [[ "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		Print_Error "$(Tf 'Invalid --pause value: %s' "$Pause")"
		return 1
	fi

	if [ "$Modus" = 'Shred' ] && ! command -v shred >/dev/null; then
		Print_Error '--mode=shred requires shred (coreutils)'
		return 1
	fi

	mkdir -p -- "$Target_Dir" || {
		Print_Error "$(Tf 'Cannot create target directory: %s' "$Target_Dir")"
		return 1
	}
}
