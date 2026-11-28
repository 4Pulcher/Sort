Resolve_Date_Token() {
	local Token="$1"

	case "$Token" in
	year) printf '%%Y|0000' ;;
	month) printf '%%m|00' ;;
	day) printf '%%d|00' ;;
	*) printf '|%s' "$Token" ;;
	esac
}
