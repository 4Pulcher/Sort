Update_Thread_Slot() {
	local SlotID=$1 Badge=$2 BadgeColor=$3 Detail=$4
	local TargetRow=$((HEADER_ROWS + SlotID))
	local Width MaxDetail
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	MaxDetail=$((Width - 28))
	((MaxDetail < 20)) && MaxDetail=20
	if ((${#Detail} > MaxDetail)); then
		Detail="...${Detail: -$((MaxDetail - 3))}"
	fi

	(
		flock -x 201
		printf '\033[%d;1H\033[K  %b[Thread %02d]%b %b%-10s%b %s' \
			"$TargetRow" "$CYAN" "$SlotID" "$RESET" "$BadgeColor" "$Badge" "$RESET" "$Detail"
	) 201>"$SLOT_DIR/tty.lock"
}
