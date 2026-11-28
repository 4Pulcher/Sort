#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V1.5.sh                                                      #
# Version : 1.5                                                               #
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
	MainTime[$Level]=$SECONDS

	echo "Parameters: $#"

	A[$Level]=$#
	B[$Level]=0

	for Item in $@; do
		B[$Level]=$((${B[$Level]} + 1))

		if [ "$Item" = "--Copy" ] || [ "$Item" = "--Move" ]; then
			echo "SET: Mode=${Item:2}"
			Mode="${Item:2}"

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

		elif [ "${Item:0:7}" = "--Dirs=" ]; then
			echo "SET: Dirs=${Item:7}"
			SubDirs=${Item:7}

		elif [ "${Item:0:10}" = "--SubDirs=" ]; then
			echo "SET: SubDirs=${Item:10}"
			BySize=${Item:10}
			if [ "$BySize" = "" ]; then BySize="Yes"; fi

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

				Time=$(stat -c '%w' "$File")
				Time=$(printf ${Time% *} | tr ' ' '~')
				Hour=${Time#*~}
				Date=${Time%~*}

				Name=${File##*/}
				if [ "$Rename" != "" ]; then
					case "${Rename,,}" in
					"short") Name=${Name%%.*} ;;
					"long") Name=$(printf "$File" | tr '/' '~' | tr ' ' '_') ;;
					"date") Name=$Date ;;
					"hour") Name=$Hour ;;
					"time") Name=$Time ;;
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
					"original")
						Ext=${File##*.}
						if [ "$Ext" = "$File" ]; then Ext=""; fi
						;;
					"mime") Ext=$(printf "$Mime" | tr '/' '.') ;;
					"mime-main") Ext=${Mime%/*} ;;
					"mime-sub") Ext=${Mime#*/} ;;
					"date") Ext=$Date ;;
					"hour") Ext=$Hour ;;
					"time") Ext=$Time ;;
					"extension") Ext=$(file -b --extension "$File" | tr -d '\n') ;;
					esac
					printf "Extension: $Ext\n"
				fi

				Class=""
				if [ "$SubDirs" != "" ]; then
					case "${SubDirs,,}" in
					"mime")
						Class=$Mime
						Class=${Class^^}
						;;
					"mime-main")
						Class=${Mime%/*}
						Class=${Class^^}
						;;
					"mime-sub")
						Class=${Mime#*/}
						Class=${Class^^}
						;;
					"date") Class=$Date ;;
					"hour") Class=$Hour ;;
					"time") Class=$Time ;;
					"extension")
						Class=$(file -b --extension "$File" | tr -d '\n')
						Class=${Class^^}
						;;
					"random") Class=$RANDOM ;;
					"random2") Class=$RANDOM$RANDOM ;;
					"random3") Class=$RANDOM$RANDOM$RANDOM ;;
					"random4") Class=$RANDOM$RANDOM$RANDOM$RANDOM ;;
					"same")
						Tmp="${Item%/*}"
						if [ "$Tmp" != "$Item" ]; then Class=$Tmp; fi
						;;
					esac
					printf "Dirs: $Class\n"
				fi

				Size=""
				if [ "$BySize" != "" ]; then
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
							Shape=""
							if [ $Width -gt $Height ]; then Shape="Wide"; elif [ $Width -lt $Height ]; then Shape="High"; else Shape="Square"; fi

							Format=""
							if [ $Width -lt 32 ] || [ $Height -lt 32 ]; then
								Format="Tiny"
							elif [ $Width -lt 512 ] || [ $Height -lt 512 ]; then
								Format="Smaller"
							elif [ $Width -lt 1024 ] || [ $Height -lt 1024 ]; then
								Format="Small"
							elif [ $Width -lt 2048 ] || [ $Height -lt 2048 ]; then
								Format="Medium"
							elif [ $Width -lt 4096 ] || [ $Height -lt 4096 ]; then
								Format="Big"
							elif [ $Width -lt 8192 ] || [ $Height -lt 8192 ]; then
								Format="Bigger"
							else
								Format="Huge"
							fi

							case "$BySize" in
							"shape") Size=$Shape ;;
							"format") Size=$Format ;;
							"dimension") Size=$Width'x'$Height ;;
							"size") Size=$Shape/$Format/$Width'x'$Height ;;
							"date") Size=$Date ;;
							"hour") Size=$Hour ;;
							"time") Size=$Time ;;
							"custom") Size=$Format/$Shape/$Width'-'$Height ;;
							"custom1") Size=$Date/$Shape/$Format/$Width'-'$Height ;;
							"custom2") Size=$Date/$Shape/$Format/$Width'-'$Height/$Time ;;
							esac
						fi
					else
						Short=("B" "KB" "MB" "GB" "TB" "PB" "EB" "ZB" "YB" "RB" "QB")
						Long=("Bytes" "KiloBytes" "MegaBytes" "GigaBytes" "TeraBytes" "PetaBytes" "ExaBytes" "ZettaBytes" "YottaBytes" "RonnaBytes" "QuettaBytes")

						Size=$(stat -c "%s" "$File" | tr -d '\n')

						Count=0
						while [ "$Size" -gt 999 ]; do
							((Count++))
							Size=$(($Size / 1000))
						done

						case "$BySize" in
						"shape") Size=${Long[$Count]} ;;
						"format") Size=$Size' '${Short[$Count]} ;;
						"dimention") Size=${Long[$Count]}/$Size' '${Short[$Count]} ;;
						"size") Size=${Long[$Count]}/$Size' '${Short[$Count]} ;;
						"date") Size=$Date ;;
						"hour") Size=$Hour ;;
						"time") Size=$Time ;;
						"custom") Size=${Long[$Count]}/$Size' '${Short[$Count]} ;;
						"custom1") Size=$Date/${Long[$Count]}/$Size' '${Short[$Count]} ;;
						"custom2") Size=$Date/${Long[$Count]}/$Size' '${Short[$Count]}/$Time ;;
						esac
					fi
					printf "SubDirs: $Size\n"
				fi

				NewDir=$(if [ "$Class" != "" ]; then printf "$Class/"; fi)$(if [ "$Size" != "" ]; then printf "$Size"; fi)
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

				NewFile="$(if [ "$NewDir" != "" ]; then printf "$NewDir/"; fi)$NewName"

				case "$Mode" in
				"Copy")
					if [ "$NewDir" != "" ]; then mkdir -v -p "$NewDir"; fi
					cp -v -f "$File" "$NewFile"
					;;
				"Move")
					if [ "$NewDir" != "" ]; then mkdir -v -p "$NewDir"; fi
					mv -v -f "$File" "$NewFile"
					;;
				*)
					if [ "$NewDir" != "" ]; then printf "Dummy-MakeDir: $NewDir\n"; fi
					printf "Dummy-Target: $NewFile\n"
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

	printf "DURATION: $(($SECONDS - ${MainTime[$Level]})) SECONDS\!\!\n\n"
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
	echo "USAGE:"
	echo
	echo "[--Add|--Copy|--Move]"
	echo
	echo "--Probe"
	echo
	echo "--Replace"
	echo
	echo "--Recursive"
	echo
	echo "--Rename=[short|long|date|hour|time|sha1sum|sha224sum|sha256sum|sha384sum|sha512sum|random|random2|random3|random4]"
	echo
	echo "--Extension=[original|mime|mime-main|mime-sub|date|hour|time|extension]"
	echo
	echo "--Dirs=[mime|mime-main|mime-sub|date|hour|time|extension|random|random2|random3|random4|same]"
	echo
	echo "--SubDirs=[format|dimension|date|hour|time|size|custom1|custom2]"
	echo "  ? custom0="
	echo "  ? custom1="
	echo "  ? custom2="
	echo
	echo "[FileList]"
	echo
fi

# +----------+
# |   END!   |
# +----------+---------------------------+
# |   THANKS FOR USING Ejder-scripts..   |
# +--------------------------------------+

echo "Thanks for using HEjder scripts!"
