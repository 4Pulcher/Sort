#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V1.2.sh                                                      #
# Version : 1.2                                                               #
# Desc    : Ejder file organizer - first generation                           #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# +--------------------------------------------------------------------+
# |                                                                    |
# |   D O   N O T   E D I T   B E N E A T H   T H I S   L I N E  !!!   |
# |                                                                    |
# +------------+-------------------------------------------------------+
# |   BEGIN:   |
# +------------+

# NewName: new name
function NewName {
	if [ "$Fext" = "" ]; then
		printf "$Dir/$Name.$Ext"
	else
		printf "$Dir/$Name.$Fext"
	fi
}

# NewCName: new c name
function NewCName {
	Count=0
	while [ -e "$New" ]; do
		((Count++))

		if [ "${Fext}" = "" ]; then
			printf "$Dir/$Name~$Count.$Ext"
		else
			printf "$Dir/$Name~$Count.$Fext"
		fi
	done
}

# SortFiles: sort files
function SortFiles {
	for Item in $@; do
		if [ "$Item" = "Replace" ] || [ "$Item" = "Move" ] || [ "$Item" = "Copy" ] || [ "$Item" = "Add" ]; then
			echo "SET: Mode=$Item"

			Mode="$Item"

		elif [ "$Item" = "Rename" ] || [ "$Item" = "SubDirs" ] || [ "$Item" = "Classes" ] || [ "$Item" = "Sizes" ]; then
			echo "SET: $Item=\"Yes\""

			eval $Item="Yes"

		elif [ -d "$Item" ]; then
			if [[ "$Item" =~ "lost+found" ]] && [ "$SubDirs" != "Yes" ] && [ "$Item" != "." ]; then echo "DIR: $Item (skipped)"; else
				echo "DIR: $Item"
				SortFiles "$Item"/*
			fi

		elif [ -f "$Item" ]; then
			echo "FILE: $Item"

			Mime=$(file -b -i "$Item")
			Mime=${Mime%%;*}

			Type=${Mime%/*}
			Ext=${Mime#*/}

			Fext=""
			Fext="$Ext" # Fext=$(grep "$Mime" /etc/mime.types | awk '{print $2}')

			echo "MIME: ${Mime^^}"
			echo "Fext: $Fext"

			if [ "$Rename" = "Yes" ]; then
				Name=$(sha256sum -b "$Item")
				Name=${Name%% *}
			else Name=${Item##*/}; fi

			if [ "$Classes" = "Yes" ]; then Dir="$Type/$Ext"; else Dir="$Ext"; fi

			if [[ ! "commando niet gevonden" =~ "$(identify)" ]] && [ "$Type" = "image" ] && [ "$Sizes" = "Yes" ]; then
				WxH=$(identify -format "%w:%h" "$Item")

				if [ "${#WxH}" -lt "3" ]; then WxH="0:0"; fi

				Width=${WxH%%:*}
				Height=${WxH##*:}

				if [ $Width -gt $Height ]; then Sub="wide"; elif [ $Width -lt $Height ]; then Sub="high"; else Sub="square"; fi

				if [ $Width -lt 500 ] || [ $Height -lt 500 ]; then Class="small-$Sub"; elif [ $Width -gt 5000 ] || [ $Height -gt 5000 ]; then Class="big-$Sub"; else Class="medium-$Sub"; fi

				Dir="$Dir/$Class/$Width-$Height"
			fi

			Dir="${Dir^^}"

			New=$(NewName)

			if [ "$Item" != "$New" ] && [ "${Item:2}" != "$New" ]; then
				case "$Mode" in
				"Replace")
					mkdir -v -p "$Dir"
					mv -v "$Item" "$New"
					;;

				"Move")
					New=$(NewCName)

					mkdir -v -p "$Dir"
					mv -v "$Item" "$New"
					;;

				"Copy")
					mkdir -v -p "$Dir"
					cp -v "$Item" "$New"
					;;

				"Add")
					New=$(NewCName)

					mkdir -v -p "$Dir"
					cp -v "$Item" "$New"
					;;

				*)
					echo "Target: $Dir/$New"
					;;
				esac
			else
				echo "Equals: $New"
			fi
		else
			echo "File ($Item) not recognized!"
		fi

		echo
	done
}

if [ $# -gt 0 ]; then
	echo "SCRIPT: ${0##*/}"

	OIFS=$IFS
	IFS=$'\n\b'

	SortFiles $@

	IFS=$OIFS

	echo "Thanks for using Ejder-scripts.."
else
	echo
	echo "${0##*/}"
	echo
	echo "Usage: ['Replace'|'Move'|'Copy'|'Add'] ['Rename'] ['SubDirs'] ['Classes'] ['Sizes'] 'FileList'"
	echo
fi

# +----------+
# |   END!   |
# +----------+---------------------------+
# |   THANKS FOR USING Ejder-scripts..   |
# +--------------------------------------+

echo "Thanks for using HEjder scripts!"
