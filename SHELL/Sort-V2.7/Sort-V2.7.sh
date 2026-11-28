#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.7.sh                                                      #
# Version : 2.7                                                               #
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

# SortMimeType: sort mime type
function SortMimeType {
	for Item in $@; do
		if [ -d "$Item" ]; then
			SortMimeType "$Item"/*
		elif [ -f "$Item" ]; then
			Dir=${Item%/*}
			Name=${Item##*/}

			Mime=$(/usr/bin/mimetype -b "$Item" | tr ' ' '.' | tr -d \\n) && Mime=${Mime^^}

			if [ "$Mime" != "" ]; then
				mkdir -v -p "$Mime"
				mv -v "$Item" "$Mime/$Name"
			fi
		fi
	done
}

if [ $# -gt 0 ]; then
	if [ -e '/usr/bin/mimetype' ]; then
		SortMimeType $@
	else
		echo "You need to install '/usr/bin/mimetype' and '/etc/mime.types' for this script!"
	fi
fi

Break

echo "Thanks for using HEjder scripts!"
