#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.13.sh                                                     #
# Version : 2.13                                                              #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# GetDimension: get dimension
function GetDimension {
	for Item in $@; do
		W=${Item%x*}
		H=${Item#*x}

		if [ "$W" -gt "$H" ]; then
			printf "Wide"

		elif [ "$W" = "$H" ]; then
			printf "Square"

		else
			printf "High"

		fi
	done
}

# GetSize: get size
function GetSize {
	for Item in $@; do
		W=${Item%x*}
		H=${Item#*x}

		if [ "$W" -lt 100 ] && [ "$H" -lt 100 ]; then
			printf "Small"

		elif [ "$W" -lt 1000 ] && [ "$H" -lt 1000 ]; then
			printf "Medium"

		elif [ "$W" -lt 5000 ] && [ "$H" -lt 5000 ]; then
			printf "Big"

		else
			printf "Super"
		fi
	done
}

# SortDirectories: sort directories
function SortDirectories {
	for Item in $@; do
		if [ -d "$Item" ]; then
			Dimension=$(GetDimension "$Item")
			Size=$(GetSize "$Item")

			if [ "$Dimension" != "" ] && [ "$Size" != "" ]; then
				mkdir -v -p "$Dimension/$Size"
				mv -v "$Item" "$Dimension/$Size/"
			fi
		fi
	done
}

if [ $# -gt 0 ]; then
	SortDirectories $@
fi

echo "Thanks for using HEjder scripts!"
