_Comp_Magic() {
	local File=$1 Count=$2

	[ -f "$File" ] || return 1
	head -c "$Count" -- "$File" 2>/dev/null | od -An -tx1 | tr -d ' \n'
}
