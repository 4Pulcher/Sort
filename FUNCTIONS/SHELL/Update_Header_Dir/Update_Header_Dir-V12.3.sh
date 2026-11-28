Update_Header_Dir() {
	local CurrentDir=$1
	local StatusRow=$((HEADER_ROWS + MAX_JOBS + 2))
	local Width MaxLen
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	MaxLen=$((Width - 18))
	((MaxLen < 20)) && MaxLen=20

	if ((${#CurrentDir} > MaxLen)); then
		CurrentDir="...${CurrentDir: -$((MaxLen - 3))}"
	fi

	(
		flock -x 201
		printf '\033[%d;1H\033[K  %bScanning:%b %s' \
			"$StatusRow" "$BLUE" "$RESET" "$CurrentDir"
	) 201>"$SLOT_DIR/tty.lock"
}
