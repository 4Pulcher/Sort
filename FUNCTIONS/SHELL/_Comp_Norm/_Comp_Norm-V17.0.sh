_Comp_Norm() {
	local Path=$1

	case "$Path" in
	-) printf './-' ;;
	-*) printf './%s' "$Path" ;;
	*) printf '%s' "$Path" ;;
	esac
}
