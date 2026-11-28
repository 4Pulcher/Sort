#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.8.sh                                                      #
# Version : 2.8                                                               #
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

# SortFileExtension: sort file extension
function SortFileExtension {
	for Item in $@; do
		if [ -d "$Item" ]; then
			printf "DIR: $Item\n"

			SortFileExtension "$Item"/*

			printf "\n"
		elif [ -f "$Item" ]; then
			printf "FILE: $Item\n"

			Name=$(printf "$Item" | tr '/' '~' | tr -d '\n')

			Extension=${Item##*.}

			if [ "$Extension" = "" ] || [ "$Extension" = "$Item" ]; then Extension="NONE"; fi

			Dir=${Extension^^}

			mkdir -v -p "$Dir"
			mv -v "$Item" "$Dir/$Name"
		fi
	done
}

if [ $# -gt 0 ]; then
	SortFileExtension $@
fi

Break

echo "Thanks for using HEjder scripts!"
