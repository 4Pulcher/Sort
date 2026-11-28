Get_Cached_Date() {
	local Key="$1|$3" Out

	Out=${Sort_Date_Cache[$Key]-}
	if [ -z "$Out" ]; then
		Out=$(date -d "${2%%.*}" "$3" 2>/dev/null) || Out=$4
		Sort_Date_Cache[$Key]=$Out
	fi
	printf '%s' "$Out"
}
