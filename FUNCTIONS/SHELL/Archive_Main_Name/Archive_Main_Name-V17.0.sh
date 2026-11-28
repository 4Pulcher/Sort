Archive_Main_Name() {
	local File=$1
	local Entries Top Name='' Extra=0

	Entries=$(Archive_List "$File") || return 1

	# Unique top-level entries (first path component)
	while IFS= read -r Entry; do
		[ -n "$Entry" ] || continue
		Entry=${Entry#./}
		Top=${Entry%%/*}
		[ -n "$Top" ] || Top=$Entry
		if [ -z "$Name" ]; then
			Name=$Top
		elif [ "$Name" != "$Top" ]; then
			Extra=$((Extra + 1))
		fi
	done <<<"$Entries"

	[ -n "$Name" ] || return 1
	[ "$Extra" -eq 0 ] || return 1

	# A directory entry lists children as <Name>/... (single-file entries do not)
	if [[ "$Entries" == *"$Name"/* ]]; then
		printf '%s' "$Name"
		return 0
	fi

	# Single file: strip one trailing extension
	printf '%s' "${Name%.*}"
}
