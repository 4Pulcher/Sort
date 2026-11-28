Write_Log() {
	[[ "$ENABLE_LOG" != "yes" || -z "$LOG_FILE" ]] && return 0
	local RawMsg=$1
	local CleanMsg Timestamp
	CleanMsg=$(printf '%b' "$RawMsg" | sed -r 's/\x1B\[[0-9;]*[mK]//g')
	Timestamp=$(date '+%H:%M:%S')
	(
		flock -x 200
		printf '[%s] %s\n' "$Timestamp" "$CleanMsg" >&200
	) 200>>"$LOG_FILE"
}
