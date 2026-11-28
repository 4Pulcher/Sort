Validate_Options() {
	case "$Modus" in
	Print | Copy | Move | Remove | Trash | Shred) ;;
	*)
		Print_Error "Unsupported mode: $Modus"
		return 1
		;;
	esac

	if [ -n "$Pause" ] && ! [[ "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		Print_Error "Invalid --pause value: $Pause"
		return 1
	fi

	if [ "$Modus" = 'Shred' ] && ! command -v shred >/dev/null; then
		Print_Error '--mode=shred requires shred (coreutils)'
		return 1
	fi

	mkdir -p -- "$Target_Dir" || {
		Print_Error "Cannot create target directory: $Target_Dir"
		return 1
	}
}
