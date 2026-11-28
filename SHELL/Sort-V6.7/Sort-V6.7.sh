#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V6.7.sh                                                      #
# Version : 6.7                                                               #
# Desc    : Optimized file organizer                                          #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder - Optimized v2.1

# --- Colors ---

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
RESET='\e[0m'

# 1. Check Requirements

declare -A Required=(
	[file]='Linux Base' [stat]='Linux Base' [cp]='Linux Base' [mv]='Linux Base' [rm]='Linux Base' [find]='Linux Base' [sha256sum]='Linux Base'
	[ffprobe]='FFMPEG'
	[identify]='ImageMagick'
)

Errors=0

for Key in "${!Required[@]}"; do
	[ ! command -v "$Key" ] &>/dev/null && {
		printf "\n${RED} ERROR:${RESET} '${Key}' command is not installed. Install: ${Required[$Key]}\!\n\n"

		((Errors++))
	}
done

[ $Errors -gt 0 ] && {
	printf "\n${RED} ERRORS:${RESET} Found \(%d\) errors;\nExiting..\n\n" "${Errors}"

	exit -1
}

# Draw_Line: draw line
function Draw_Line {
	local w=$(tput cols) s="${1:-=}"

	printf -v l "%${w}s" ""

	echo "${l// /$s}" | cut -c 1-"$w"
}

# 2. Setup & Safety

OIFS=$IFS

# Exit: exit
function Exit {
	IFS=$OIFS
	exit $1
}

# Break: break
function Break {
	printf "\n\nTerminated by user\!\!\n\n"
	Exit 2
}

trap Break INT
trap Exit EXIT

shopt -s dotglob

# --- Helper Functions ---

# Get_MIME: get mime
function Get_MIME {
	printf "%s" "$(file -b --mime-type "$1" 2>/dev/null)"
}

# Get_SHA256Sum: get sha256 sum
function Get_SHA256Sum {
	printf "%s" "$(sha256sum -b "$1" | cut -d' ' -f1)"
}

# Get_File_Name: get file name
function Get_File_Name {
	local b=$(basename "$1")

	printf "%s" "${b%.*}"
}

# Get_File_Ext: get file ext
function Get_File_Ext {
	printf "%s" "${1##*.}"
}

# Get_File_Size: get file size
function Get_File_Size {
	local S=$(stat -c %s "$1" 2>/dev/null)

	printf "%d" "${S:-0}"
}

# Get_File_Birth: get file birth
function Get_File_Birth {
	local B=$(stat -c %W "$1" 2>/dev/null)

	printf "%s" "${B:-0}"
}

# Get_File_Creation_Time: get file creation time
function Get_File_Creation_Time {
	printf "%s" "$(stat -c %w "$1" 2>/dev/null)"
}

# Get_File_Access_Time: get file access time
function Get_File_Access_Time {
	printf "%s" "$(stat -c %x "$1" 2>/dev/null)"
}

# Get_File_Modification_Time: get file modification time
function Get_File_Modification_Time {
	printf "%s" "$(stat -c %y "$1" 2>/dev/null)"
}

# Date Helpers

# Get_Date_Part: get date part
function Get_Date_Part {
	local T=$(Get_File_Birth "$1")

	[ "$T" != "0" ] && {
		date -d "@$T" "$2" 2>/dev/null || printf "$3"
	}
}

# Media Helpers

# Get_Image_WxH: get image wx h
function Get_Image_WxH {
	local res=$(timeout 10s identify -format "%wx%h" "$1" 2>/dev/null)

	printf "${res:-0x0}"
}

# Get_Video_WxH: get video wx h
function Get_Video_WxH {
	local res=$(timeout 10s ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null)

	printf "${res:-0x0}"
}

# Get_WxH_Format: get wx h format
function Get_WxH_Format {
	[[ ! "$1" =~ [0-9]+x[0-9]+ ]] && {
		printf "0x0"

		return
	}

	local W=${1%%x*} H=${1##*x}

	local MAX=$W

	[ "$H" -gt "$W" ] && MAX=$H

	local L="HUGE"

	if [ "$W" -eq 0 ]; then
		L="ZERO"

	elif [ "$MAX" -lt 512 ]; then
		L="SMALLER"

	elif [ "$MAX" -lt 1024 ]; then
		L="SMALL"

	elif [ "$MAX" -lt 2048 ]; then
		L="MEDIUM"

	elif [ "$MAX" -lt 4096 ]; then
		L="BIG"

	elif [ "$MAX" -lt 8096 ]; then
		L="BIGGER"
	fi

	local A="SQUARE"

	if [ "$W" -gt "$H" ]; then
		A="WIDE"

	elif [ "$W" -lt "$H" ]; then
		A="HIGH"

	fi

	printf "$L/$A"
}

# Resolve_Path_Segment: resolve path segment
function Resolve_Path_Segment {
	local Req="${1,,}" File="$2" Res=""

	case "$Req" in
	"year")
		Res=$(Get_Date_Part "$File" "+%Y" "0000")
		;;

	"month")
		Res=$(Get_Date_Part "$File" "+%m" "00")
		;;

	"day")
		Res=$(Get_Date_Part "$File" "+%d" "00")
		;;

	"year+month")
		Res=$(Get_Date_Part "$File" "+%Y/%m" "0000/00")
		;;

	"year+month+day")
		Res=$(Get_Date_Part "$File" "+%Y/%m/%d" "0000/00/00")
		;;

	"extension")
		local e=$(Get_File_Ext "$File")

		Res=${e^^}
		;;

	"mime")
		Res=${MIME^^}
		;;

	"mime-main")
		Res=${MIMEMain^^}
		;;

	"mime-sub")
		Res=${MIMESub^^}
		;;

	"size" | "format" | "size+format" | "format+size")
		[[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]] && {
			local WxH=$(
				[ "$MIMEMain" == "image" ] && Get_Image_WxH "$File" || Get_Video_WxH "$File"
			)

			local Fmt=$(Get_WxH_Format "$WxH")

			[[ "$Req" == "size" ]] && Res="$WxH" || {
				[[ "$Req" == "format" ]] && Res="$Fmt" || Res="$Fmt/$WxH"
			}
		} || {
			local S=$(Get_File_Size "$File")

			S=${S:-0}

			local T=$S N=0 Div=1000

			local U=("B" "KB" "MB" "GB" "TB" "PB" "EB" "ZB" "YB" "RB" "QB")

			if [[ "$Req" == "size+format" ]]; then
				Div=1024

				U=("B" "KiB" "MiB" "GiB" "TiB" "PiB" "EiB" "ZiB" "YiB" "RiB" "QiB")

			elif [[ "$Req" == "format"* ]]; then
				U=("Byte" "Kilo" "Mega" "Giga" "Tera" "Peta" "Exa" "Zetta" "Yotta" "Rona" "Quetta")

			fi

			while [ "$T" -gt "$((Div - 1))" ] && [ "$N" -lt "5" ]; do
				((N++))

				T=$((T / Div))
			done

			case "$Req" in
			"size")
				Res="$T${U[$N]}"
				;;

			"size+format")
				Res="${T}_${U[$N]}"
				;;

			"format")
				Res="${U[$N]}"
				;;

			"format+size")
				Res="${U[$N]}/$T"
				;;
			esac
		}
		;;

	"created")
		Res=$(Get_File_Creation_Time "$File")
		;;

	"modified")
		Res=$(Get_File_Modification_Time "$File")
		;;

	"accessed")
		Res=$(Get_File_Access_Time "$File")
		;;

	"shasum" | "sha1deep" | "sha1sum" | "sha224sum" | "sha256deep" | "sha256sum" | "sha384sum" | "sha512sum")
		Res=$(/usr/bin/$Req -b "$File" | cut -d' ' -f1)
		;;

	"random" | "random[1-9]")
		local count="${X#random}"

		count="${count:-1}"

		Res=""

		for ((i = 0; i < count; i++)); do
			Res+="${RANDOM}"
		done
		;;

	*)
		Res="$1"
		;;

	esac

	printf "$Res"
}

# --- Main Logic ---

declare -a Total Counter

Current=0

# Sort: sort
function Sort {
	((Current++))

	Total[$Current]=$#

	Counter[$Current]=0

	local Item
	for Item in "$@"; do
		case "${Item,,}" in
		"--pause="*)
			((Total[$Current]--))

			Pause=${Item#*=}
			;;

		"--type="*)
			((Total[$Current]--))

			Type=${Item#*=}
			;;

		"--mode="*)
			((Total[$Current]--))

			Mode=${Item#*=}
			;;

		"--recursive")
			((Total[$Current]--))

			Recursive="yes"
			;;

		"--replace")
			((Total[$Current]--))

			Replace="yes"
			;;

		"--rename="*)
			((Total[$Current]--))

			Rename=${Item#*=}
			;;

		"--extension="*)
			((Total[$Current]--))

			Extension=${Item#*=}
			;;

		"--dirs="*)
			((Total[$Current]--))

			Dirs=${Item#*=}
			;;

		"--subdirs="*)
			((Total[$Current]--))

			SubDirs=${Item#*=}
			;;

		*)
			((Counter[$Current]++))

			printf "LEVELS"

			for ((i = 1; i <= $Current; i++)); do
				printf ": [%d]=%d/%d" "$i" "${Counter[$i]}" "${Total[$i]}"
			done

			printf "\n"

			if [[ -L "$Item" ]]; then
				printf "\n${RED}SKIP:${RESET} Symlink $Item\n\n"

			elif [[ -d "$Item" ]]; then
				Draw_Line "="

				[ "$Recursive" = "yes" ] && {
					printf "\n${BLUE}DIRECTORY:${RESET} Entering ($Item)\n\n"

					Draw_Line ">"

					Sort "$Item"/*

					[ "$Mode" = "move" ] && printf "${BLUE}REMOVE-DIRECTORY:${RESET} %s\n" "$(rmdir -v "$Item")"
				} || {
					printf "\n${RED}DIR:${RESET} Skipping!\n\n"
				}

				Draw_Line "="

			elif [[ -f "$Item" ]]; then
				Draw_Line "-"

				printf "\n$GREEN FILE:$YELLOW $Item$RESET\n\n"

				MIME=$(Get_MIME "$Item")

				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}

				printf "$YELLOW MIME:$RESET $MIME\n"

				if [ -z "$Type" ] || [[ "${MIME^^}" == *"${Type^^}"* ]]; then
					# Build Target Path

					local D=$(Resolve_Path_Segment "$Dirs" "$Item")

					local SD=$([ -n "$SubDirs" ] && Resolve_Path_Segment "$SubDirs" "$Item" || printf "")

					local Loc="."

					[ -n "$D" ] && Loc="${D^^}"

					[ -n "$SD" ] && Loc="$Loc/${SD^^}"

					printf "${YELLOW} TARGET:${RESET} $Loc\n"

					# Build Target Name

					local Name=$(Get_File_Name "$Item")

					[ -n "$Rename" ] && Name=$(Resolve_Path_Segment "$Rename" "$Item")

					local Ext=$(Get_File_Ext "$Item")

					[ -n "$Extension" ] && {
						Ext=$(Resolve_Path_Segment "$Extension" "$Item")

						Ext=${Ext,,}
						Ext=${Ext//\//.}
						Ext=${Ext// /_}
					}

					local NewName="$Name.$Ext"

					[ "$Replace" != "yes" ] && {
						local C=0

						local BaseName="$Name"

						while [ -e "$Loc/$NewName" ]; do
							((C++))

							NewName="$BaseName-($C).$Ext"
						done
					}

					printf "${YELLOW} NEW-NAME:${RESET} %s\n" "$NewName"

					# Action

					[ -n "$Mode" ] && {
						printf "\n${YELLOW} NEW DIRECTORY:${RESET} %s\n" "$(mkdir -v -p "$Loc")"

						case "$Mode" in
						"move")
							printf "\n${RED} MOVE:${RESET} %s\n" "$(mv -v -f "$Item" "$Loc/$NewName" 2>&1)"
							;;

						"copy")
							printf "\n${RED} COPY:${RESET} %s\n" "$(cp -v -f "$Item" "$Loc/$NewName" 2>&1)"
							;;

						"remove")
							printf "\n${RED} REMOVE:${RESET} %s\n" "$(rm -v -f "$Item" 2>&1)"
							;;
						esac
					} || {
						printf "${GREEN} DUMMY:${RESET} %s -> %s/%s\n" "$Item" "$Loc" "$NewName"
					}

					[ -n "$Pause" ] && sleep "$Pause"

					Draw_Line "-"
				fi

			else
				[[ -e "$Item" ]] && {
					printf "\n${RED}ERROR:${RESET} Unknown file type ($Item)\n\n"
				} || {
					printf "\n${RED}SKIP:${RESET} Missing ($Item)\n\n"
				}
			fi
			;;
		esac
	done

	((Current--))
}

# Execution

[ $# -gt 0 ] && {
	Sort "$@"

	printf "\n${GREEN}---DONE---${RESET}\n\n"

	Exit 0
} || {
	cat <<EOF
${GREEN}
📂	Sort.sh v2.1 | Media-Intelligent File Organizer

$(Draw_Line "=")

	Developed by:
		HEjder

	SYNTAX:
		Sort.sh [OPTIONS] [FILE/DIR LIST]

$(Draw_Line "=")
${RESET}
EOF
}

echo "Thanks for using HEjder scripts!"
