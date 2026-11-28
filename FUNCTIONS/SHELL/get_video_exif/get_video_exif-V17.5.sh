#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : get_video_exif.sh                                                 #
# Version : 1.0                                                               #
# Desc    : Legacy FUNCTIONS adapters - video dimensions / duration           #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Compatibility layer for the original FUNCTIONS library: the lowercase
# get_video_* helpers expected by Sort.sh (V15.1). Each adapter is a thin
# wrapper over the modern functions/ffmpeg toolkit (ffprobe) and prints its
# result on stdout, returning non-zero on failure
# (127 = ffmpeg/ffprobe not installed).

# Load the modern toolkit this layer is built on
_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../functions" && pwd)

. "$_LIB_DIR/ffmpeg/ffmpeg.sh"

# ---------------------------------------------------------------------------
# Video geometry / timing
# ---------------------------------------------------------------------------

# get_video_dimention <file> : video dimensions as WxH (e.g. 1920x1080)
get_video_dimention() {
	[ -e "$1" ] || return 1
	Get_Media_WxH "$1"
}

# get_video_duration <file> : duration as a filename-safe HH-MM-SS string
get_video_duration() {
	local Seconds H M S

	Seconds=$(Get_Duration "$1") || return $?
	Seconds=${Seconds%.*}
	Seconds=${Seconds:-0}

	H=$((Seconds / 3600))
	M=$(((Seconds % 3600) / 60))
	S=$((Seconds % 60))

	printf '%02d-%02d-%02d' "$H" "$M" "$S"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
