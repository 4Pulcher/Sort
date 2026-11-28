Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		Log_Print 'ERROR: Unsupported mode: %s\n' "$Mode"
		return 1
		;;
	esac
	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		Log_Print 'ERROR: --pause must be a number.\n'
		return 1
	fi
	if [[ -n "$MAX_JOBS" && ! "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
		Log_Print 'ERROR: --jobs must be positive integer.\n'
		return 1
	fi
}
