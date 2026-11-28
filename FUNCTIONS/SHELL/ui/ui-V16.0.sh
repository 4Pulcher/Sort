#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : ui.sh                                                             #
# Version : 1.0                                                               #
# Desc    : Terminal display                                                  #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Terminal display helpers: themed separator lines for the TUI output.

Draw_Line() {
	local Width Symbol

	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	Symbol=${1:-=}

	# Use the requested symbol for every column in the separator.
	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
