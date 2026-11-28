Find_Copy_In() {
	local File=$1
	local Dir=$2
	local Algo=${3:-sha256}
	local TargetHash Sum Candidate

	[ -f "$File" ] && [ -d "$Dir" ] || return 1

	TargetHash=$(Get_Hash "$Algo" "$File") || return $?

	find "$Dir" -type f -print0 2>/dev/null |
		while IFS= read -r -d '' Candidate; do
			# Skip the file itself (same inode via hardlink or identical path).
			[[ "$Candidate" -ef "$File" ]] && continue
			Sum=$(Get_Hash "$Algo" "$Candidate") || continue
			[[ "$Sum" == "$TargetHash" ]] && printf '%s\n' "$Candidate"
		done
}
