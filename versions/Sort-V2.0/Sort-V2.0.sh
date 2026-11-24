#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.0.sh                                                      #
# Version : 2.0                                                               #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

if ! [ -e /usr/bin/file ]; then
	printf "Binairy 'file' not found!\n" >/dev/tty
	exit 1
fi

# SortExtension: sort extension
function SortExtension {
	for Item in $@; do
		if [ -d $Item ]; then
			SortExtension $Item/*
		else
			if [ -e $Item ]; then
				Short=${Item#./}

				Name=$(echo $Short | tr '/' '~')
				Name=${Name%.*}

				Mime=$(file -b --mime-type "$Item")
				Ext=${Mime##*/}

				if [ ${#Ext} -gt 0 ]; then
					Dir=${Ext^^}
				else
					Dir='?'
				fi

				mkdir -v -p $Dir

				mv -v "$Item" "$Dir/$Name.${Ext,,}"
			else
				printf "Error: $Item (does not exists!)\n" >/dev/tty
			fi
		fi
	done
}

if [ $# -gt 0 ]; then
	printf "Sorting..\n"

	SortExtension $@

	printf "Done!\n"
fi

echo "Thanks for using HEjder scripts!"
