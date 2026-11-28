Resolve_Joined_Tokens() {
	local Input="$1"
	local File="$2"
	local Sep Parts Token Pair DateFmt DefaultFmt Out

	Sep=$(printf "%s" "$Input" | awk -F"'" '{print $2}')
	Parts=$(printf "%s" "${Input,,}" | sed -E "s/'[^']*'/ /g")

	for Token in $Parts; do
		case "$Token" in
		year | month | day)
			Pair=$(Resolve_Date_Token "$Token")
			DateFmt+="${Pair%%|*}$Sep"
			DefaultFmt+="${Pair#*|}$Sep"
			;;
		size | format)
			Out+="$(Resolve_Path_Segment "$Token" "$File")$Sep"
			;;
		esac
	done

	if [[ -n "$DateFmt" ]]; then
		DateFmt=${DateFmt%"$Sep"}
		DefaultFmt=${DefaultFmt%"$Sep"}
		Get_Date_Part "$File" "+$DateFmt" "$DefaultFmt"
	else
		printf "%s" "${Out%"$Sep"}"
	fi
}
