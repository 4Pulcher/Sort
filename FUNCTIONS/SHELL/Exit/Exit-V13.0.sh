Exit() {
	local Status=${1:-0}

	# Unset the EXIT trap immediately to prevent infinite recursion when 'exit' runs.
	trap - EXIT

	printf 'Waiting for background jobs to finish...\n'
	wait

	# Restore original shell word-splitting behavior.
	IFS=$OIFS

	printf 'Finished.\n'
	exit "$Status"
}
