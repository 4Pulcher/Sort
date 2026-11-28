Print_Color() {
	local Name=${1,,}
	shift

	local Color
	case "$Name" in
	red) Color=$C_RED ;;
	green) Color=$C_GREEN ;;
	yellow) Color=$C_YELLOW ;;
	blue) Color=$C_BLUE ;;
	magenta) Color=$C_MAGENTA ;;
	cyan) Color=$C_CYAN ;;
	white) Color=$C_WHITE ;;
	gray) Color=$C_GRAY ;;
	bold) Color=$C_BOLD ;;
	dim) Color=$C_DIM ;;
	underline) Color=$C_UNDERLINE ;;
	*) Color='' ;;
	esac

	printf '%s%s%s\n' "$Color" "$*" "$C_RESET"
}
