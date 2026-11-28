#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V4.2.sh                                                      #
# Version : 4.2                                                               #
# Desc    : CamelCase file organizer                                          #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder

# Break: break
function Break {
	IFS=$OIFS
	printf "\n"
	exit
}

trap Break INT

shopt -s dotglob

# Sort: sort
function Sort {
	Total=$(($# + 1))
	Current=0
	for Item in $@; do
		case ${Item,,} in
		"--pause="*)
			((Total--))
			Pause=${Item#*=}
			printf "Pause: $Pause\n"
			;;

		"--probe")
			((Total--))
			Probe="yes"
			printf "Probe: $Probe\n"
			;;

		"--copy")
			((Total--))
			Mode="copy"
			printf "Mode: $Mode\n"
			;;

		"--move")
			((Total--))
			Mode="move"
			printf "Mode: $Mode\n"
			;;

		"--remove")
			((Total--))
			Mode="remove"
			printf "Mode: $Mode\n"
			;;

		"--recursive")
			((Total--))
			Recursive="yes"
			printf "Recursive: $Recursive\n"
			;;

		"--replace")
			((Total--))
			Replace="yes"
			printf "Replace: $Replace\n"
			;;

		"--rename="*)
			((Total--))
			Rename=${Item#*=}
			printf "Rename: $Rename\n"
			;;

		"--extension="*)
			((Total--))
			Extension=${Item#*=}
			printf "Extension: $Extension\n"
			;;

		"--dirs="*)
			((Total--))
			Dirs=${Item#*=}
			printf "Directory: $Dirs\n"
			;;

		"--subdirs="*)
			((Total--))
			SubDirs=${Item#*=}
			printf "Directory (sub): $SubDirs\n"
			;;

		*)
			((Current++))
			printf "POSITION: $Current/$Total\n"

			if [ -d "$Item" ] && [ "$Recursive" = "yes" ]; then
				printf "DIR: $Item\n"

				Sort "$Item"/*

			elif [ -f "$Item" ]; then
				printf "FILE-->\n"
				printf "SOURCE: $Item\n"

				OLD=$(sha256sum -b "$Item" | tr -d '\n')
				OLD=${OLD%% *}

				if [ "${Probe,,}" = "yes" ]; then
					printf "PROBE -->\n"

					case "${Mode,,}" in
					"copy")
						NEW=""
						printf "PROBE: $(mkdir -p "PROBE") "
						printf "PROBE: $(while [ "$OLD" != "$NEW" ]; do
							cp -v -f "$Item" "PROBE/${Item##*/}"
							NEW=$(sha256sum -b "PROBE/${Item##*/}" | tr -d '\n')
							NEW=${NEW%% *}
						done)\n"
						File="PROBE/${File##*/}"
						;;
					"move")
						NEW=""
						printf "PROBE: $(mkdir -p "PROBE") "
						printf "PROBE: $(while [ "$OLD" != "$NEW" ]; do
							cp -v -f "$Item" "PROBE/${Item##*/}"
							NEW=$(sha256sum -b "PROBE/${Item##*/}" | tr -d '\n')
							NEW=${NEW%% *}
						done)\n"
						File="PROBE/${Item##*/}"
						printf "PROBE: $(rm -v -f "$Item")\n"
						;;
					*)
						printf "Probing...!\n"
						;;
					esac
				else
					File="$Item"
				fi

				# VARIABLES:

				printf "VARIABLES -->\n"

				MIME=$(file --mime-type "$File" | tr -d '\n')
				MIME=${MIME##* }
				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}

				#NAMES

				case "${Rename,,}" in
				"sha256sum")
					Name=$OLD
					;;
				*)
					Name=${File##*/}
					Name=${Name%%.*}
					;;
				esac

				printf "Name: $Name\n"

				#EXTENSIONS

				case "${Extension,,}" in
				"mime")
					Ext=$(printf $MIME | tr '/' '.')
					;;
				"mime-main")
					Ext=$MIMEMain
					;;
				"mime-sub")
					Ext=$MIMESub
					;;
				*)
					Ext=${File##*/}
					Ext=${Ext#*.}
					;;
				esac

				printf "Extension: $Ext\n"

				#DIRECTIRIES

				if [ "$Dirs" != "" ]; then
					case "${Dirs,,}" in
					"mime")
						Dir=${MIME^^}
						;;
					"mime-main")
						Dir=${MIMEMain^^}
						;;
					"mime-sub")
						Dir=${MIMESub^^}
						;;
					"extension")
						if [ "$Ext" = "" ]; then Dir=${File##*.}; else Dir=$Ext; fi
						;;
					*)
						Dir=${File%/*}
						;;
					esac

					printf "Directory: $Dir\n"
				fi

				#SUB-DIRECTIRIES

				if [ "$SubDirs" != "" ]; then
					if [ "${MIMEMain,,}" = "image" ] || [ "${MIMEMain,,}" = "video" ]; then

						if [ "${MIMEMain,,}" = "image" ]; then
							WxH=$(identify -format "%wx%hXX" "$File" | tr -d '\n')
							WxH=${WxH%%XX*}
						fi
						if [ "${MIMEMain,,}" = "video" ]; then WxH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$File" | tr -d '\n'); fi

						printf "WxH: $WxH\n"

						W=${WxH%%x*}
						H=${WxH##*x}

						if [ "$WxH" = "" ] || [ "$W" = "" ] || [ "$H" = "" ]; then
							FileSize="0x0"
						else
							FileSize=$WxH
						fi

						FileFormat=$(
							if [ "$W" -lt "32" ] && [ "$H" -lt "32" ]; then
								printf "TINY"
							elif [ "$W" -lt "512" ] && [ "$H" -lt "512" ]; then
								printf "SMALLER"
							elif [ "$W" -lt "1024" ] && [ "$H" -lt "1024" ]; then
								printf "SMALL"
							elif [ "$W" -lt "2048" ] && [ "$H" -lt "2048" ]; then
								printf "MEDIUM"
							elif [ "$W" -lt "4096" ] && [ "$H" -lt "4096" ]; then
								printf "BIG"
							elif [ "$W" -lt "8192" ] && [ "$H" -lt "8192" ]; then
								printf "BIGGER"
							elif [ "$W" -lt "16384" ] && [ "$H" -lt "16384" ]; then
								printf "SUPER"
							else
								printf "HUGE"
							fi

							printf "/"

							if [ "$W" -gt "$H" ]; then
								printf "WIDE"
							elif [ "$W" -lt "$H" ]; then
								printf "HIGH"
							else
								printf "SQUARE"
							fi
						)

						case "${SubDirs,,}" in
						"size")
							SubDir=$FileSize
							;;

						"format")
							SubDir=$FileFormat
							;;

						"format+size")
							SubDir="$FileFormat/$FileSize"
							;;

						*)
							SubDir=""
							;;
						esac
					else
						FileSize=$(stat -c "%s" "$File" | tr -d '\n')

						case "${SubDirs,,}" in
						"size")
							SubDir=$FileSize
							;;

						"format")
							Format=("Byte" "KiloByte" "MegaByte" "GigaByte" "TerraByte" "PetaByte" "ExaByte" "ZettaByte" "YottaByte" "RonnaByte" "QuettaByte")

							Tmp=$FileSize
							N=0
							while [ "$Tmp" -gt "999" ]; do
								((N++))
								Tmp=$(($Tmp / 1000))
							done

							SubDir="${Format[$N]}"
							;;

						"format+size")
							#Format=("B" "KB" "MB" "GB" "TB" "PB" "EB" "ZB" "YB" "RB" "QB")
							Format=("Byte" "KiloByte" "MegaByte" "GigaByte" "TerraByte" "PetaByte" "ExaByte" "ZettaByte" "YottaByte" "RonnaByte" "QuettaByte")

							Tmp=$FileSize
							N=0
							while [ "$Tmp" -gt "999" ]; do
								((N++))
								Tmp=$(($Tmp / 1000))
							done

							SubDir="${Format[$N]}/$Tmp"
							;;

						*)
							SubDir=""
							;;
						esac
					fi

					printf "Sub-directory: $SubDir\n"
				fi

				# ACTIONS

				printf "ACTIONS -->\n"

				#PRE-ACTION

				if [ "$Dir" != "" ] && [ "$SubDir" != "" ]; then
					Location="$Dir/$SubDir"

				elif [ "$Dir" != "" ]; then
					Location="$Dir"

				elif [ "$SubDir" != "" ]; then
					Location="$SubDir"
				else
					Location="$(pwd)"
				fi

				NewName="$Name.$Ext"
				if [ "$Replace" != "yes" ]; then
					C=0
					while [ -e "$Location/$NewName" ]; do
						((C++))
						NewName="$Name-($C).$Ext"
					done
				fi

				#ACTION

				if [ "${Probe,,}" = "yes" ] || [ "${Mode,,}" = "move" ]; then
					printf "TARGET: $(mkdir -v -p "$Location")"
					printf "TARGET: $(mv -v -f "$File" "$Location/$NewName")\n"

				elif [ "${Mode,,}" = "copy" ]; then
					printf "TARGET: $(mkdir -v -p "$Location")"
					printf "TARGET: $(cp -v -f "$File" "$Location/$NewName")\n"

				elif [ "${Mode,,}" = "remove" ]; then
					printf "TARGET: $(if [ -e "$Location/$NewName" ]; then rm -v -f "$Location/$NewName"; else printf "Not found!"; fi)\n"
				else
					printf "TARGET:  $File --> $Location/$NewName\n"
				fi

				# PAUSE

				if [ "$Pause" != "" ]; then
					printf "Pause: $Pause\n"
					sleep $Pause
				fi

				printf "<---DONE\n\n"

			else
				printf "Error: unknown: $Item\n"
			fi
			;;
		esac
	done
}

if [ $# -gt 0 ]; then
	OIFS=$IFS
	IFS=$'\n\b'

	Sort $@
	printf "\n"

	IFS=$OFS
else
	echo "Sort.sh"
	echo "by HEjder"
	echo ""
	echo "USAGE:"
	echo ""
	echo "Sort.sh [--Copy|--Move] [--Recursive] [--Replace] [--Rename=(1)] [--Extension=(2)] [--Dirs=(3)] [--SubDirs=(4)] *"
	echo ""
	echo "1)"
	echo "  sha256sum"
	echo "  * 'original'"
	echo ""
	echo "2)"
	echo "  mime"
	echo "  mime-main"
	echo "  mime-sub"
	echo "  * 'original'"
	echo ""
	echo "3)"
	echo "  mime"
	echo "  mime-main"
	echo "  mime-sub"
	echo "  extension"
	echo "  * 'original'"
	echo ""
	echo "4)"
	echo "  size"
	echo "  format"
	echo "  format+size"
	echo "  * 'none'"
	echo ""
fi

echo "Thanks for using HEjder scripts!"
