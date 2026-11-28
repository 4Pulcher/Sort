Exit() {
	local Status=${1:-0}
	trap - EXIT

	printf 'Waiting for all background jobs to finish...\n'
	wait

	IFS=$OIFS
	printf 'Finished.\n'
	exit "$Status"
}
