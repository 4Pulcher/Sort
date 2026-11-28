Exit() {
	local Status=${1:-0}
	trap - EXIT
	wait
	if [[ "$TUI_ACTIVE" == "yes" ]]; then
		local BottomRow=$((HEADER_ROWS + MAX_JOBS + 3))
		printf '\033[%d;1H\033[?25h\n' "$BottomRow"
	fi
	[[ -n "$SLOT_DIR" && -d "$SLOT_DIR" ]] && rm -rf -- "$SLOT_DIR"
	IFS=$OIFS
	exit "$Status"
}
