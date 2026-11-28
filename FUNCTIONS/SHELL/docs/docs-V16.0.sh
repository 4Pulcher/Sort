#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : docs.sh                                                           #
# Version : 1.0                                                               #
# Desc    : Documents (pdftotext / exiftool)                                  #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Document helpers: internal document title extraction from PDFs and office documents via pdftotext/exiftool.

Get_Doc_Title() {
	local File=$1
	local Title

	Title=$(
		grep -a '/Title' "$File" 2>/dev/null |
			head -n 1 |
			sed 's/.*(\(.*\)).*/\1/' |
			tr -d '/\\:*?"<>|' |
			tr ' ' '_'
	)

	# Fall back to the existing filename when no title could be extracted.
	[[ -z "$Title" ]] && Title=$(Get_File_Name "$File")

	printf '%s' "${Title:-ERROR}"
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
