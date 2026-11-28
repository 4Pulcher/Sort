#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : system.sh                                                         #
# Version : 1.0                                                               #
# Desc    : System process control                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Process control helpers: clean exit and Ctrl+C break handling.

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

Break() {
	printf '\nTerminated by user!\n'
	Exit 130
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
