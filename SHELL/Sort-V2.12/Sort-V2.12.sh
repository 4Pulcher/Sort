#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.12.sh                                                     #
# Version : 2.12                                                              #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

if [ ! -e '/bin/identify' ]; then
	echo "ImageMagick is not installad!"
	exit 1
fi

# SortFiles: sort files
function SortFiles() {
	for Item in $@; do
		if [ "$Item" = "Copy" ] || [ "$Item" = "Move" ]; then
			Mode=$Item

		elif [ -d "$Item" ]; then
			SortFiles "$Item"/*

		elif [ -f "$Item" ]; then
			Mime=$(file -b -i "$Item")
			SMime=${Mime%%;*}

			Type=${SMime%%/*}
			Ext=${SMime##/*}

			if [ "$Type" = "image" ]; then
				WxH=$(identify -format "%w:%h" "$Item")
				Dir=${WxH%%:*}
				Dir=$Type/$Ext/${WxH##*:}x$Dir
			else
				Dir=$Type/$Ext
			fi

			Name=$(sha512sum -b "$Item")
			Name=${Name%% *}

			case "$Mode" in
			"Copy")
				mkdir -v -p "$Dir"
				cp -v "$Item" "$Dir/$Name"
				;;
			"Move")
				mkdir -v -p "$Dir"
				mv -v "$Item" "$Dir/$Name"
				;;
			*)
				echo "SOURCE: $Item"
				echo "TARGET: $Dir/$Name"
				;;
			esac
		else
			echo "File ($Item) not recognized!"
		fi
		echo
	done
}

if [ $# -gt 0 ]; then
	echo "Sorting.."

	SortFiles $@

	echo "DONE!"
fi

echo "Thanks for using HEjder scripts!"
