#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : get_image_exif.sh                                                 #
# Version : 1.0                                                               #
# Desc    : Legacy FUNCTIONS adapters - image dimensions / size / form        #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Compatibility layer for the original FUNCTIONS library: the lowercase
# get_image_* helpers expected by Sort.sh (V15.1). Each adapter is a thin
# wrapper over the modern functions/imagemagick toolkit (identify / magick)
# and prints its result on stdout, returning non-zero on failure
# (127 = ImageMagick not installed).

# Load the modern toolkit this layer is built on
_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../functions" && pwd)

. "$_LIB_DIR/imagemagick/imagemagick.sh"

# ---------------------------------------------------------------------------
# Image geometry
# ---------------------------------------------------------------------------

# get_image_dimension <file> : dimensions as WxH (e.g. 1920x1080)
get_image_dimension() {
	[ -e "$1" ] || return 1
	Get_Image_WxH "$1"
}

# get_image_size_Category <file> : pixel-size class as a directory name
get_image_size_Category() {
	local WxH W

	WxH=$(Get_Image_WxH "$1") || return $?
	W=${WxH%x*}

	if [ "$W" -lt 64 ]; then
		printf 'Icon'
	elif [ "$W" -lt 640 ]; then
		printf 'Small'
	elif [ "$W" -lt 1920 ]; then
		printf 'Medium'
	elif [ "$W" -lt 3840 ]; then
		printf 'Large'
	else
		printf 'Huge'
	fi
}

# get_image_size_Form <file> : aspect form - Square / Portrait / Landscape
get_image_size_Form() {
	local WxH W H

	WxH=$(Get_Image_WxH "$1") || return $?
	W=${WxH%x*}
	H=${WxH#*x}

	if [ "$W" -eq "$H" ]; then
		printf 'Square'
	elif [ "$H" -gt "$W" ]; then
		printf 'Portrait'
	else
		printf 'Landscape'
	fi
}

[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
