#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.11.sh                                                     #
# Version : 2.11                                                              #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Break: break
function Break {
	IFS=$OIFS

	echo "End!"
}

trap Break INT

OIFS=$IFS
IFS=$'\n\b'

# SortExifImageSize: sort exif image size
function SortExifImageSize {
	for Item in $@; do
		if [ -d "$Item" ]; then
			SortExifImageSize "$Item"/*
		elif [ -f "$Item" ]; then
			Dir=${Item%/*}
			Name=${Item##*/}

			ImageSize=$(/usr/bin/exiftool "$Item" | grep "Image Size" | tr -d \\n) && ImageSize=${ImageSize##*: }

			if [ "$ImageSize" != "" ]; then
				mkdir -v -p "$Dir/$ImageSize"
				mv -v "$Item" "$Dir/$ImageSize/$Name"
			fi
		fi
	done
}

if [ $# -gt 0 ]; then
	if [ -e '/usr/bin/exiftool' ]; then
		SortExifImageSize $@
	else
		echo "You need to install '/usr/bin/exiftool' for this script!"
	fi
fi

Break

echo "Thanks for using HEjder scripts!"
