Get_Size_Label() {
	local SIZE=$1
	local MODE=$2
	local DIV=$DIV_DEC
	local IDX=0
	local TMP=$SIZE
	local -a UNITS=("${SIZE_UNITS_DEC[@]}")

	case "$MODE" in
	bin)
		DIV=$DIV_BIN
		UNITS=("${SIZE_UNITS_BIN[@]}")
		;;
	format)
		UNITS=("${FORMAT_UNITS[@]}")
		;;
	esac

	while ((TMP > DIV - 1 && IDX < 5)); do
		((IDX++))
		TMP=$((TMP / DIV))
	done

	printf "%s%s" "$TMP" "${UNITS[$IDX]}"
}
