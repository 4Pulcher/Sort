#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.5.sh                                                      #
# Version : 2.5                                                               #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

shopt -s globstar

if [ ! -e '/bin/identify' ]; then
	printf "ImageMagick is not installad!\n"
	exit 1
fi

# SortSize: sort size
function SortSize() {
	for Location in $@; do
		if [ -d $Location ]; then
			for File in $Location/**/*; do
				if [ -e "$File" ] && [ ! -d $"File" ]; then
					Size=$(identify -format "%b" "$File")
					Size=${Size:0:-1}

					Dir=0
					while [ "$Size" -gt "5000" ]; do
						((Dir++))
						let "Size = $Size - 5000"
					done

					mkdir -v -p "$Location/SIZE-$Dir"

					mv -v "$File" "$Location/SIZE-$Dir/"
				fi
			done
		fi
	done
}

if [ $# -gt 0 ]; then
	printf "Sorting by Size:\n\n"

	SortSize $@

	printf "\nCleaning empty files and directories:\n"
	find . -empty -print -delete

	printf "\nDone!\n"
fi

echo "Thanks for using HEjder scripts!"
