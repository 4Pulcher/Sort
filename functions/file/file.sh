#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : file.sh                                                           #
# Version : 1.0                                                               #
# Desc    : File attributes via coreutils / file(1)                           #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# File attribute helpers: MIME detection (file(1)), name/extension splitting, size, birth/creation/access/modification timestamps (stat) and date parts (date).

Get_MIME() {
	local File=$1
	local MIME

	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	printf '%s' "${MIME:-ERROR}"
}

Get_File_Name() {
	local Name=${1##*/}

	printf '%s' "${Name%.*}"
}

Get_File_Ext() {
	local BaseName=${1##*/}

	# A name without a dot (or a hidden name such as ".profile") has no
	# extension. Otherwise, return the text following the final dot.
	if [[ "$BaseName" != *.* || "$BaseName" == .* && "$BaseName" != *.*.* ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}

Get_File_Size() {
	local File=$1
	local Size

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}

Get_File_Birth() {
	local File=$1
	local Time

	Time=$(stat -c '%W' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Creation_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%w' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Access_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%x' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Modification_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_Date_Part() {
	local File=$1
	local Format=$2
	local Fallback=$3
	local Time

	Time=$(Get_File_Birth "$File")

	if [[ "$Time" != "0" ]]; then
		date -d "@$Time" "$Format" 2>/dev/null
	else
		printf '%s' "$Fallback"
	fi
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
