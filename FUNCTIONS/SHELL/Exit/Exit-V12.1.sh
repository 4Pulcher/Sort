Exit() {
	local Status=${1:-0}
	trap - EXIT
	wait
	IFS=$OIFS
	exit "$Status"
}
