Draw_Line() {
	local W
	W=$(tput cols)
	printf '%*s\n' "$W" '' | tr ' ' "${1:-=}" | cut -c1-"$W"
}
