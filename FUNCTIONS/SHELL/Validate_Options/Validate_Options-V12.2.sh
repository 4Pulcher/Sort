Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf 'ERROR: Unsupported mode: %s\n' "$Mode"
		return 1
		;;
	esac

	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf 'ERROR: --pause must be a non-negative number.\n'
		return 1
	fi

	if [[ -n "$MAX_JOBS" && ! "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
		printf 'ERROR: --jobs must be a positive integer.\n'
		return 1
	fi

	if [[ "$Mode" == "trash" ]] && ! command -v trash-put >/dev/null 2>&1; then
		printf 'ERROR: --mode=trash requires trash-put (trash-cli).\n'
		return 1
	fi

	if [[ "$Mode" == "shred" ]] && ! command -v shred >/dev/null 2>&1; then
		printf 'ERROR: --mode=shred requires shred (coreutils).\n'
		return 1
	fi
}
