Draw_Line() {
	local Width Symbol

	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80} # Default to 80 columns if running non-interactively
	Symbol=${1:-=}

	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
}
