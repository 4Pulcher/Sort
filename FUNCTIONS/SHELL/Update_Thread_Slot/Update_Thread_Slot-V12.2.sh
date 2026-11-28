Update_Thread_Slot() {
	local SlotID=$1
	local Badge=$2
	local BadgeColor=$3
	local Detail=$4

	local TargetRow=$((HEADER_ROWS + SlotID))
	local Width MaxDetail
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}

	# Truncate detail string so it never wraps onto the next thread's row
	MaxDetail=$((Width - 28))
	((MaxDetail < 20)) && MaxDetail=20
	if ((${#Detail} > MaxDetail)); then
		Detail="...${Detail: -$((MaxDetail - 3))}"
	fi

	# Lock stdout briefly so cursor positioning + line clear are atomic
	(
		flock -x 201
		printf '\033[%d;1H\033[K  %b[Thread %02d]%b %b%-10s%b %s' \
			"$TargetRow" "$CYAN" "$SlotID" "$RESET" "$BadgeColor" "$Badge" "$RESET" "$Detail"
	) 201>"$SLOT_DIR/tty.lock"
}
