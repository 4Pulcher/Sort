Exit() {
	local Status=${1:-0}
	trap - EXIT

	wait

	# Restore cursor visibility if TUI was active
	if [[ "$TUI_ACTIVE" == "yes" ]]; then
		local BottomRow=$((HEADER_ROWS + MAX_JOBS + 3))
		printf '\033[%d;1H\033[?25h\n' "$BottomRow"
	fi

	# Remove temporary thread slot tracking directory
	[[ -n "$SLOT_DIR" && -d "$SLOT_DIR" ]] && rm -rf -- "$SLOT_DIR"

	IFS=$OIFS
	exit "$Status"
}
