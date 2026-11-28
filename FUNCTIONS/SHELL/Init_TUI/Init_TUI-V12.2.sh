Init_TUI() {
	TUI_ACTIVE="yes"
	local Width
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}

	local Rule
	printf -v Rule '%*s' "$Width" ''
	Rule=${Rule// /=}

	# Clear screen, move cursor to (1,1), hide cursor (\033[?25l)
	printf '\033[2J\033[1;1H\033[?25l'

	# --- Static Header Section (Rows 1 to 8) ---
	printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
	printf '%b  Sort.sh v2.4%b | Media-Intelligent File Organizer\n' "$BOLD" "$RESET"
	printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
	printf '  %bMode:%b %-10s | %bThreads:%b %-4s | %bRecursive:%b %-5s | %bLog:%b %s\n' \
		"$YELLOW" "$RESET" "${Mode:-DRY-RUN}" \
		"$YELLOW" "$RESET" "$MAX_JOBS" \
		"$YELLOW" "$RESET" "$Recursive" \
		"$YELLOW" "$RESET" "${LOG_FILE:-OFF}"
	printf '  %bDirs:%b %-10s | %bSubDirs:%b %-10s | %bRename:%b %s\n' \
		"$CYAN" "$RESET" "${Dirs:-<source>}" \
		"$CYAN" "$RESET" "${SubDirs:-<none>}" \
		"$CYAN" "$RESET" "${Rename:-<original>}"
	printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
	printf '  %bACTIVE WORKER THREADS:%b\n' "$BOLD" "$RESET"
	printf '%b%s%b\n' "$DIM" "${Rule//=/-}" "$RESET"

	# --- Pre-draw empty thread slots (Rows 9 to 9+MAX_JOBS-1) ---
	local Slot
	for ((Slot = 1; Slot <= MAX_JOBS; Slot++)); do
		local Row=$((HEADER_ROWS + Slot))
		printf '\033[%d;1H\033[K  %b[Thread %02d]%b %bIDLE%b\n' \
			"$Row" "$CYAN" "$Slot" "$RESET" "$DIM" "$RESET"
	done

	# Footer separator below thread pool
	local FooterRow=$((HEADER_ROWS + MAX_JOBS + 1))
	printf '\033[%d;1H\033[K%b%s%b\n' "$FooterRow" "$BLUE" "$Rule" "$RESET"
}
