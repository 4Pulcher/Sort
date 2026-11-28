Exit() {
	local Status=${1:-0}

	# Prevent this EXIT handler from recursively invoking itself when exit runs.
	trap - EXIT

	printf '%s\n' "$(T 'Waiting for background jobs to finish...')"
	wait

	# Restore the original shell field separator.
	IFS=$OIFS

	printf '%s\n' "$(T 'Finished.')"
	exit "$Status"
}
