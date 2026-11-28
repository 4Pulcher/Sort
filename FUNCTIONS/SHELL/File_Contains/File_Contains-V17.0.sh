File_Contains() {
	local Needle=$1
	local Haystack=$2
	local Encoding Content

	[ -f "$Needle" ] && [ -f "$Haystack" ] || return 1
	[ -s "$Needle" ] || return 1
	command -v grep >/dev/null || return 127

	# Text fast path: grep -F matches the whole needle, newlines included.
	Encoding=$(file -b --mime-encoding -- "$Needle" 2>/dev/null)
	if [ "$Encoding" != "binary" ] && command -v file >/dev/null; then
		Content=$(cat -- "$Needle") || return 1
		grep -qaF -- "$Content" "$Haystack"
		return $?
	fi

	# Binary-safe path (needle contains NUL bytes): compare hex streams.
	command -v od >/dev/null || return 127
	local NeedleHex HaystackHex
	NeedleHex=$(od -An -v -tx1 -- "$Needle" 2>/dev/null | tr -d ' \n') || return 1
	HaystackHex=$(od -An -v -tx1 -- "$Haystack" 2>/dev/null | tr -d ' \n') || return 1
	[[ "$HaystackHex" == *"$NeedleHex"* ]]
}
