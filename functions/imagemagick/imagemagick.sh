#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : imagemagick.sh                                                    #
# Version : 1.0                                                               #
# Desc    : Images via ImageMagick                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Image helpers: width x height and camera metadata via ImageMagick identify, plus WxH tier formatting shared by the size/format resolvers.

Get_Image_WxH() {
	local File=$1
	local Resolution

	Resolution=$(
		identify -ping -format '%wx%h\n' -- "$File" 2>/dev/null |
			head -n 1 |
			tr -d '\r\n '
	)

	printf '%s' "${Resolution:-0x0}"
}

Get_Image_Meta() {
	local File=$1
	local Date

	Date=$(
		timeout 5s ffprobe \
			-v error \
			-show_entries format_tags=date_time_original \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	[[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$File")

	printf '%s' "${Date:-ERROR}"
}

Get_WxH_Format() {
	local Input=$1
	local Width Height MaxDimension
	local Level="TINY"
	local Aspect="SQUARE"

	# Reject malformed dimension strings before doing numeric comparisons.
	if [[ ! "$Input" =~ ^[0-9]+x[0-9]+$ ]]; then
		printf 'ERROR'
		return 1
	fi

	if [[ "$Input" == "0x0" ]]; then
		printf 'ZERO'
		return 0
	fi

	Width=${Input%%x*}
	Height=${Input##*x}

	# Use the larger side to assign a resolution tier.
	MaxDimension=$Width
	((Height > Width)) && MaxDimension=$Height

	((MaxDimension > 32)) && Level="MINI"
	((MaxDimension > 512)) && Level="SMALLER"
	((MaxDimension > 1024)) && Level="SMALL"
	((MaxDimension > 2048)) && Level="MEDIUM"
	((MaxDimension > 4096)) && Level="BIG"
	((MaxDimension > 8192)) && Level="BIGGER"
	((MaxDimension > 16384)) && Level="HUGE"

	# Describe the image/video orientation.
	((Width > Height)) && Aspect="WIDE"
	((Width < Height)) && Aspect="HIGH"

	printf '%s/%s' "$Level" "$Aspect"
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
