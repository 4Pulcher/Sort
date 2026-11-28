Validate_Options() {
	# Ensure Mode is recognized
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf '%bERROR:%b Unsupported mode: %s\n' "$RED" "$RESET" "$Mode"
		return 1
		;;
	esac

	# Ensure --pause is a valid integer or decimal number
	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf '%bERROR:%b --pause must be a non-negative number of seconds.\n' \
			"$RED" "$RESET"
		return 1
	fi

	# Warn user about legacy flags that have no active implementation
	[[ -n "$MAX_JOBS" && "$MAX_JOBS" != 4 ]] &&
		printf '%bWARNING:%b --jobs is currently not implemented.\n' "$YELLOW" "$RESET"

	[[ "$Compare" == "yes" ]] &&
		printf '%bWARNING:%b --compare is currently not implemented.\n' "$YELLOW" "$RESET"

	# Check optional external utilities required for destructive modes
	if [[ "$Mode" == "trash" ]] && ! command -v trash-put >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=trash requires trash-put (trash-cli).\n' "$RED" "$RESET"
		return 1
	fi

	if [[ "$Mode" == "shred" ]] && ! command -v shred >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=shred requires shred (coreutils).\n' "$RED" "$RESET"
		return 1
	fi
}
