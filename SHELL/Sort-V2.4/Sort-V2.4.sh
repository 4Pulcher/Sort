#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.4.sh                                                      #
# Version : 2.4                                                               #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

shopt -s globstar

if [ ! -e '/bin/identify' ]; then
	printf "ImageMagick is not installad!\n"
	exit 1
fi

# SortWxH: sort wx h
function SortWxH() {
	for Location in $@; do
		if [ -d "$Location" ]; then
			for File in $Location/**/*; do
				if [ -e "$File" ] && ! [ -d "$File" ]; then
					WH=$(identify -format "%g" "$File")

					mkdir -v -p "$Location/$WH"

					Name=${File##*/}
					New="$Location/$WH/$Name"

					Count=0
					while [ -e "$New" ]; do
						((Count++))
						New="$Location/$WH/${Name%.*}-($Count).${Name##*.}"
					done

					mv -v "$File" "$New"
				fi
			done

			printf "\nCleaning empty files and directories:\n"
			find "$Location" -empty -print -delete
		fi
	done
}

if [ $# -gt 0 ]; then
	printf "Sorting by Width_Height:\n\n"

	SortWxH $@

	printf "\nDone!\n"
fi

echo "Thanks for using HEjder scripts!"
