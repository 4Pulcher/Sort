#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V1.3.sh                                                      #
# Version : 1.3                                                               #
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

# SortFiles: sort files
function SortFiles {
	Time[$Level]=$SECONDS

	echo "Parameters: $#"

	A[$Level]=$#
	B[$Level]=0

	for Item in $@; do
		B[$Level]=$((${B[$Level]} + 1))

		if [ "$Item" = "--Copy" ] || [ "$Item" = "--Move" ]; then
			echo "SET: Mode=${Item:2}"
			Mode="${Item:2}"

		elif [ "$Item" = "--Force" ]; then
			echo "SET: Force=Yes"
			Force="Yes" ## TO DO !!

		elif [ "$Item" = "--Probe" ]; then
			echo "SET: Probe=Yes"
			Probe="Yes"

		elif [ "$Item" = "--Replace" ]; then
			echo "SET: Replace=Yes"
			Replace="Yes"

		elif [ "$Item" = "--Recursive" ]; then
			echo "SET: Recursive=Yes"
			Recursive="Yes"

		elif [ "${Item:0:9}" = "--Rename=" ]; then
			echo "SET: Rename=${Item:9}"
			Rename=${Item:9}

		elif [ "${Item:0:12}" = "--Extension=" ]; then
			echo "SET: Extension=${Item:12}"
			Extension=${Item:12}

		elif [ "${Item:0:10}" = "--SubDirs=" ]; then
			echo "SET: SubDirs=${Item:10}"
			SubDirs=${Item:10}

		elif [ "$Item" = "--BySize" ]; then
			echo "SET: BySize=Yes"
			BySize="Yes"

		else
			echo
			for N in ${!A[@]}; do
				printf "Level:$N[${A[$N]}:${B[$N]}] "
			done
			echo
			echo
			if [ -d "$Item" ]; then
				printf "\nDIR: "
				if [ "$Recursive" = "Yes" ] && [[ ! "$Item" =~ "lost+found" ]] && [ "$Item" != ".." ]; then
					((Level++))

					printf "$Item:\n"
					SortFiles "$Item"/*

					((Level--))
				else
					printf "$Item: Skipped\!\n"
				fi
			elif [ -f "$Item" ]; then
				FileBegin=$SECONDS

				printf "Item: $Item\n"

				File=$Item
				if [ "$Probe" = "Yes" ]; then
					printf "Probe:"
					TMP="TMP/${Item##*/}"
					case "$Mode" in
					"Copy")
						mkdir -v -p "TMP"
						cp -v -f "$Item" "$TMP"
						File=$TMP
						;;
					"Move")
						mkdir -v -p "TMP"
						mv -v -f "$Item" "$TMP"
						File=$TMP
						;;
					*)
						echo "New dir: TMP"
						echo "TMP: $Item -> $TMP"
						File=$TMP
						;;
					esac
					printf "File: $File\n"
				fi

				Mime=$(xdg-mime query filetype "$File" | tr -d '\n')
				if [ "$Mime" = "" ]; then Mime=$(file -b --mime-encoding "$File" | tr -d '\n'); fi
				printf "MIME: $Mime\n"

				Name=${File##*/}
				if [ "$Rename" != "" ]; then
					case "${Rename,,}" in
					"short") Name=${Name%%/*} ;;
					"long") Name=$(printf "$File" | tr '/' '~' | tr ' ' '_') ;;
					"sha1sum")
						Name=$(sha1sum -b "$File")
						Name=${Name%% *}
						;;
					"sha224sum")
						Name=$(sha224sum -b "$File")
						Name=${Name%% *}
						;;
					"sha256sum")
						Name=$(sha256sum -b "$File")
						Name=${Name%% *}
						;;
					"sha384sum")
						Name=$(sha384sum -b "$File")
						Name=${Name%% *}
						;;
					"sha512sum")
						Name=$(sha512sum -b "$File")
						Name=${Name%% *}
						;;
					"random") Name=$RANDOM ;;
					"random2") Name=$RANDOM$RANDOM ;;
					"random3") Name=$RANDOM$RANDOM$RANDOM ;;
					"random4") Name=$RANDOM$RANDOM$RANDOM$RANDOM ;;
					esac
				fi
				printf "Name: $Name\n"

				Ext=""
				if [ "$Extension" != "" ]; then
					case "${Extension,,}" in
					"original") Ext=${File##*.} ;;
					"mime") Ext=$(printf "$Mime" | tr '/' '.') ;;
					"mime-main") Ext=${Mime%/*} ;;
					"mime-sub") Ext=${Mime#*/} ;;
					"extension") Ext=$(file -b --extension "$File" | tr -d '\n') ;;
					esac
					printf "Extension: $Ext\n"
				fi

				Class=""
				if [ "$SubDirs" != "" ]; then
					case "${SubDirs,,}" in
					"mime") Class=$Mime ;;
					"mime-main") Class=${Mime%/*} ;;
					"mime-sub") Class=${Mime#*/} ;;
					"extension") Class=$(file -b --extension "$File" | tr -d '\n') ;;
					"random") Class=$RANDOM ;;
					"random2") Class=$RANDOM$RANDOM ;;
					"random3") Class=$RANDOM$RANDOM$RANDOM ;;
					"random4") Class=$RANDOM$RANDOM$RANDOM$RANDOM ;;
					esac
					printf "SubDirs: $Class\n"
				fi

				Size=""
				if [ "$BySize" = "Yes" ]; then
					if [ "${Mime%/*}" = "image" ] || [ "${Mime%/*}" = "video" ]; then
						Width=""
						Height=""

						Info=$(exiftool "$File")

						Width=$(echo "$Info" | grep -F 'Image Width' | awk '{print $4}' | tr -d ':' | tr -d '\n')
						if [ "$Width" = "" ]; then Width=$(printf "$Info" | grep -F 'Display Width' | awk '{print $4}' | tr -d ':' | tr -d '\n'); fi

						Height=$(echo "$Info" | grep -F 'Image Height' | awk '{print $4}' | tr -d ':' | tr -d '\n')
						if [ "$Height" = "" ]; then Height=$(printf "$Info" | grep -F 'Display Height' | awk '{print $4}' | tr -d ':' | tr -d '\n'); fi

						if [ "${Type,,}" = "image" ] && [ "$Height" = "" ] && [ "$Width" = "" ]; then
							WxH=$(identify -format "%w-%h" "$File" | tr -d '\n')
							Width=${WxH%-*}
							Height=${WxH#*-}
						fi

						if [ "$Width" != "" ] && [ "$Height" != "" ]; then
							if [ $Width -gt $Height ]; then Size="wide"; elif [ $Width -lt $Height ]; then Size="high"; else Size="square"; fi

							if [ $Width -lt 32 ] || [ $Height -lt 32 ]; then
								Size="tiny-$Size"
							elif [ $Width -lt 512 ] || [ $Height -lt 512 ]; then
								Size="smaller-$Size"
							elif [ $Width -lt 1024 ] || [ $Height -lt 1024 ]; then
								Size="small-$Size"
							elif [ $Width -lt 2048 ] || [ $Height -lt 2048 ]; then
								Size="medium-$Size"
							elif [ $Width -lt 4096 ] || [ $Height -lt 4096 ]; then
								Size="big-$Size"
							elif [ $Width -lt 8192 ] || [ $Height -lt 8192 ]; then
								Size="bigger-$Size"
							else
								Size="huge-$Size"
							fi

							Size=${Size^^}/$Width'-'$Height
						fi
					else
						Numbers=("Bytes" "KiloBytes" "MegaBytes" "GigaBytes" "TeraBytes" "PetaBytes" "ExaBytes" "ZettaBytes" "YottaBytes" "RonnaBytes" "QuettaBytes")

						Size=$(stat -c "%s" "$File" | tr -d '\n')

						Count=0
						while [ "$Size" -gt 999 ]; do
							((Count++))
							Size=$(($Size / 1000))
						done
						Size=${Numbers[$Count]}/$Size
					fi
					printf "Size: $Size\n"
				fi

				NewDir=$(if [ "$Class" != "" ]; then printf "${Class^^}/"; fi)$(if [ "$Size" != "" ]; then printf "${Size^^}"; fi)
				printf "NewDir: $NewDir\n"

				NewName=$Name$(if [ "$Ext" != "" ]; then printf ".$Ext"; fi)
				if [ "$Replace" != "Yes" ]; then
					Count=0
					while [ -e "$NewDir$NewName" ]; do
						((Count++))
						NewName=$Name.$Count.$(if [ "$Ext" != "" ]; then printf ".$Ext"; fi)
					done
				fi
				printf "NewName: $NewName\n"

				case "$Mode" in
				"Copy")
					if [ "$NewDir" != "" ]; then mkdir -v -p "$NewDir"; fi
					cp -v -f "$File" "$(if [ "$NewDir" != "" ]; then printf "$NewDir/"; fi)$NewName"
					;;
				"Move")
					if [ "$NewDir" != "" ]; then mkdir -v -p "$NewDir"; fi
					mv -v -f "$File" "$(if [ "$NewDir" != "" ]; then printf "$NewDir/"; fi)$NewName"
					;;
				*)
					if [ "$NewDir" != "" ]; then printf "Dummy-MakeDir: $NewDir\n"; fi
					printf "Dummy-Target: $(if [ "$NewDir" != "" ]; then printf "$NewDir/"; fi)$NewName\n"
					;;
				esac

				printf "FileDuration: $(($SECONDS - $FileBegin)) seconds\!\n\n"
			else
				printf "\nFile ($Item) not recognized\!\n\n"
			fi
		fi
	done
	unset A[$Level]
	unset B[$Level]

	printf "DURATION: $((SECONDS - ${Time[$Level]})) SECONDS\!\!\n\n"
}

if [ $# -gt 0 ]; then
	echo "SCRIPT: ${0##*/}"

	OveralTime=$SECONDS

	OIFS=$IFS
	IFS=$'\n\b'

	Level=0
	SortFiles $@

	IFS=$OIFS

	echo
	echo "OVER-ALL-DURATION: $(($SECONDS - $OveralTime)) SECONDS\!\!"

	echo "Thanks for using Ejder-scripts.."
else
	echo
	echo "${0##*/}"
	echo
	echo "USAGE: ['--Copy'|'--Move'] ['--Probe'] ['--Replace'] ['--Recursive'] ['--Rename=[short|long|sha1sum|sha224sum|sha256sum|sha384sum|sha512sum|random|random2|random3|random4]'] ['--Extension=[mime|mime-main|mime-sub|extension]'] ['--SubDirs=[mime|mime-main|mime-sub|extension|random|random2|random3|random4]'] ['--BySize'] 'FileList'"
	echo
fi

# +----------+
# |   END!   |
# +----------+---------------------------+
# |   THANKS FOR USING Ejder-scripts..   |
# +--------------------------------------+

echo "Thanks for using HEjder scripts!"
