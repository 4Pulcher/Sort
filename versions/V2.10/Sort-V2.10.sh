#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V2.10.sh                                                     #
# Version : 2.10                                                              #
# Desc    : Prototype micro script                                            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder

# FindImages: find images
function FindImages {
	for Item in $@; do
		if [ -d "$Item" ]; then
			echo "$0: Directory: $Item"
			FindImages $Item/*
		elif [ -f "$Item" ]; then
			echo "$0: File: $Item"

			MIME=$(file --mime-type "$Item" | tr -d '\n')
			MIME=${MIME##* }
			MIMEMain=${MIME%/*}
			MIMESub=${MIME#*/}

			if [ "$MIMEMain" = "image" ]; then
				Images+=("$Item")
			fi
		else
			echo "$0: Error: file type!"
		fi
	done
}

if [ $# -gt 0 ]; then
	declare -a Images=()

	FindImages $@

	if [ "${#Images[@]}" -gt 0 ]; then
		java -cp ~/BASH SortImages ${Images[@]}
	fi

	unset Images
fi

echo "Thanks for using HEjder scripts!"
