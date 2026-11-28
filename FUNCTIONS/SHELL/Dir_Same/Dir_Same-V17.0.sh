Dir_Same() {
	local DirA=$1
	local DirB=$2
	local Algo=${3:-sha256}
	local Out

	Out=$(Dir_Diff "$DirA" "$DirB" "$Algo") || return $?
	# Identical trees produce only SAME lines (or no lines at all).
	! printf '%s\n' "$Out" | grep -qv $'^SAME\t'
}
