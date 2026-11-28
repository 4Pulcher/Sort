Exit() {
	local Status=${1:-0}

	# Prevent this EXIT handler from recursively invoking itself when exit runs.
	trap - EXIT

	printf 'Waiting for background jobs to finish...\n'
	wait

	# Restore the original shell field separator.
	IFS=$OIFS

	printf 'Finished.\n'
	exit "$Status"
}
