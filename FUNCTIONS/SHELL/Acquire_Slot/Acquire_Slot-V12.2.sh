Acquire_Slot() {
	local Slot
	while true; do
		for ((Slot = 1; Slot <= MAX_JOBS; Slot++)); do
			# mkdir is atomic on POSIX filesystems—acts as a lock-free slot claim
			if mkdir "$SLOT_DIR/slot_$Slot" 2>/dev/null; then
				printf '%d' "$Slot"
				return 0
			fi
		done
		sleep 0.05
	done
}
