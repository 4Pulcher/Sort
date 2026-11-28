Log_Print() {
	local FormatStr=$1
	shift

	# Print to stdout (screen)
	# shellcheck disable=SC2059
	printf "$FormatStr" "$@"

	# If --log is enabled, strip ANSI codes and append to logfile
	if [[ "$ENABLE_LOG" == "yes" && -n "$LOG_FILE" ]]; then
		# shellcheck disable=SC2059
		local CleanMsg
		CleanMsg=$(printf "$FormatStr" "$@" | sed -r 's/\x1B\[[0-9;]*[mK]//g')
		printf '%s' "$CleanMsg" >>"$LOG_FILE"
	fi
}
