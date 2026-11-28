Human_From_Bytes() {
	local S=$1 Frac=0 U=0
	local -a Unit=('B' 'K' 'M' 'G' 'T')

	while [ "$S" -ge 1024 ] && [ "$U" -lt 4 ]; do
		Frac=$((S % 1024))
		S=$((S / 1024))
		U=$((U + 1))
	done
	if [ "$U" -eq 0 ]; then
		printf '%s%s' "$S" "${Unit[$U]}"
	else
		printf '%s.%s%s' "$S" "$((Frac * 10 / 1024))" "${Unit[$U]}"
	fi
}
