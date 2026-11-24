#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.2.sh                                                      #
# Version : 2.2                                                               #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

if ! [ -e /usr/bin/identify ]; then
	printf "ImageMagick is not installad!\n" >/dev/tty
	exit 1
fi

OIFS=$IFS
IFS=$'\n\r'

# SortWxH: sort wx h
function SortWxH {
	for Item in $@; do
		if [ -d $Item ]; then
			SortWxH $Item/*
		else
			if [ -e $Item ]; then
				WxH=$(identify -format "%w:%h" $Item)

				mkdir -v -p $WxH

				Name=${Item#./}

				Name=$(echo $Name | tr '/' '~')

				cp -v $Item $WxH/$Name
			else
				printf "Error: $Item (does not exists!)\n" >/dev/tty
			fi
		fi
	done
}

if [ $# -gt 0 ]; then
	printf "Sorting..\n"

	SortWxH $@

	printf "Cleaning..\n"

	find . -empty -print -delete

	printf "\nDone!\n"
fi

IFS=$OIFS

echo "Thanks for using HEjder scripts!"
