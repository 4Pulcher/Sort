Find_Duplicates() {
	local Dir=$1
	local Algo=${2:-sha256}
	local Sum File

	[ -d "$Dir" ] || return 1

	find "$Dir" -type f ! -empty -print0 2>/dev/null |
		while IFS= read -r -d '' File; do
			Sum=$(Get_Hash "$Algo" "$File") || continue
			printf '%s\t%s\n' "$Sum" "$File"
		done | sort | awk -F'\t' '
		$1 == prev { if (prevfile != "") print prevfile; print $2; prevfile="" ; seen=1 ; prev=$1 ; next }
		{ if (seen) print " --- " ; seen=0 ; prev=$1 ; prevfile=$2 }
	'
}
