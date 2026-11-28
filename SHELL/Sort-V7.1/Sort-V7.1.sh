#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V7.1.sh                                                      #
# Version : 7.1                                                               #
# Desc    : Readonly-sections file organizer                                  #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

shopt -s dotglob

trap 'IFS=$OIFS; printf "\nTerminated by user\n"; exit 1' INT

# ===== CONSTANTS =====

readonly OIFS=$IFS
readonly DIV_DEC=1000
readonly DIV_BIN=1024

readonly BOLD='\e[1m'
readonly BLUE='\e[34m'
readonly GREEN='\e[32m'
readonly RED='\e[31m'
readonly YELLOW='\e[33m'
readonly BOLDBLUE='\e[34m'
readonly BOLDGREEN='\e[32m'
readonly BOLDRED='\e[31m'
readonly BOLDYELLOW='\e[33m'
readonly RESET='\e[0m'

readonly REQUIRED_CMDS=(
	file
	stat
	cp
	mv
	rm
	find
	md5sum
	sha1sum
	sha224sum
	sha256sum
	sha384sum
	sha512sum
	ffprobe
)

readonly SIZE_UNITS_DEC=(B KB MB GB TB PB)
readonly SIZE_UNITS_BIN=(B KiB MiB GiB TiB)
readonly FORMAT_UNITS=(Byte Kilo Mega Giga Tera)

# ===== VARIABLES =====

Current=0
Pause=""
Type=""
Mode=""
Recursive=""
Replace=""
Rename=""
Title=""
Extension=""
Dirs=""
SubDirs=""
MIME=""
MIMEMain=""
MIMESub=""

# ===== ARRAYS =====

declare -a Total Counter

# ===== REQUIREMENTS =====

for CMD in "${REQUIRED_CMDS[@]}"; do
	command -v "$CMD" >/dev/null 2>&1 || {
		printf "$RED ERROR:$RESET Missing command: %s\n" "$CMD"
		exit 10
	}
done

# ===== HELPERS =====

Get_MD5Sum() { md5sum -b "$1" | cut -d' ' -f1; }
Get_SHA256Sum() { sha256sum -b "$1" | cut -d' ' -f1; }
Get_MIME() { file -b --mime-type "$1" 2>/dev/null; }
Get_File_Name() { basename "$1" | sed 's/\.[^.]*$//'; }
Get_File_Ext() { printf "%s" "${1##*.}"; }
Get_File_Size() { stat -c %s "$1" 2>/dev/null || printf "0"; }
Get_File_Birth() { stat -c %W "$1" 2>/dev/null || printf "0"; }
Get_File_Creation_Time() { stat -c %w "$1" 2>/dev/null; }
Get_File_Access_Time() { stat -c %x "$1" 2>/dev/null; }
Get_File_Modification_Time() { stat -c %y "$1" 2>/dev/null; }

# Get_Date_Part: get date part
Get_Date_Part() {
	local T
	T=$(Get_File_Birth "$1")
	[[ "$T" != "0" ]] && date -d "@$T" "$2" 2>/dev/null || printf "%s" "$3"
}

# Get_WxH: get wx h
Get_WxH() {
	timeout 10s ffprobe -v error \
		-select_streams v:0 \
		-show_entries stream=width,height \
		-of csv=s=x:p=0 "$1" 2>/dev/null || printf "0x0"
}

# Get_WxH_Format: get wx h format
Get_WxH_Format() {
	[[ ! "$1" =~ ^[0-9]+x[0-9]+$ ]] && {
		printf "ZERO/ZERO"
		return
	}

	local W=${1%%x*}
	local H=${1##*x}
	local MAX=$W
	local SIZE="HUGE"
	local ASPECT="SQUARE"

	((H > W)) && MAX=$H

	if ((W == 0 || H == 0)); then
		SIZE="ZERO"
	elif ((MAX < 512)); then
		SIZE="SMALLER"
	elif ((MAX < 1024)); then
		SIZE="SMALL"
	elif ((MAX < 2048)); then
		SIZE="MEDIUM"
	elif ((MAX < 4096)); then
		SIZE="BIG"
	elif ((MAX < 8096)); then
		SIZE="BIGGER"
	fi

	((W > H)) && ASPECT="WIDE"
	((H > W)) && ASPECT="HIGH"

	printf "%s/%s" "$SIZE" "$ASPECT"
}

# Sanitize: sanitize
Sanitize() {
	printf "%s" "$1" | tr -d '/\\:*?"<>|' | tr ' ' '_'
}

# Get_Tag: get tag
Get_Tag() {
	ffprobe -v error -show_entries "$2" -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

# Get_Doc_Title: get doc title
Get_Doc_Title() {
	local T
	T=$(grep -a '/Title' "$1" | head -n1 | sed 's/.*(\(.*\)).*/\1/')
	[[ -z "$T" ]] && Get_File_Name "$1" || Sanitize "$T"
}

# Get_Image_Meta: get image meta
Get_Image_Meta() {
	local T
	T=$(timeout 5s ffprobe -v error -show_entries format_tags=make,model -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | tr '
' ' ')
	[[ -z "${T// /}" ]] && Get_File_Name "$1" || Sanitize "$T"
}

# Get_Audio_Info: get audio info
Get_Audio_Info() {
	local T
	T=$(timeout 5s ffprobe -v error -show_entries format_tags=artist,title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | tr '
' '-' | sed 's/-$//')
	[[ -z "$T" ]] && Get_File_Name "$1" || Sanitize "$T"
}

# Get_Video_Title: get video title
Get_Video_Title() {
	local T
	T=$(timeout 10s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null)
	[[ -z "$T" ]] && Get_File_Name "$1" || Sanitize "$T"
}

# Get_Size_Label: get size label
Get_Size_Label() {
	local SIZE=$1
	local MODE=$2
	local DIV=$DIV_DEC
	local IDX=0
	local TMP=$SIZE
	local -a UNITS=("${SIZE_UNITS_DEC[@]}")

	case "$MODE" in
	bin)
		DIV=$DIV_BIN
		UNITS=("${SIZE_UNITS_BIN[@]}")
		;;
	format)
		UNITS=("${FORMAT_UNITS[@]}")
		;;
	esac

	while ((TMP > DIV - 1 && IDX < 5)); do
		((IDX++))
		TMP=$((TMP / DIV))
	done

	printf "%s%s" "$TMP" "${UNITS[$IDX]}"
}

# Resolve_Date_Token: resolve date token
Resolve_Date_Token() {
	local Token="$1"

	case "$Token" in
	year) printf '%%Y|0000' ;;
	month) printf '%%m|00' ;;
	day) printf '%%d|00' ;;
	*) printf '|%s' "$Token" ;;
	esac
}

# Resolve_Joined_Tokens: resolve joined tokens
Resolve_Joined_Tokens() {
	local Input="$1"
	local File="$2"
	local Sep Parts Token Pair DateFmt DefaultFmt Out

	Sep=$(printf "%s" "$Input" | awk -F"'" '{print $2}')
	Parts=$(printf "%s" "${Input,,}" | sed -E "s/'[^']*'/ /g")

	for Token in $Parts; do
		case "$Token" in
		year | month | day)
			Pair=$(Resolve_Date_Token "$Token")
			DateFmt+="${Pair%%|*}$Sep"
			DefaultFmt+="${Pair#*|}$Sep"
			;;
		size | format)
			Out+="$(Resolve_Path_Segment "$Token" "$File")$Sep"
			;;
		esac
	done

	if [[ -n "$DateFmt" ]]; then
		DateFmt=${DateFmt%"$Sep"}
		DefaultFmt=${DefaultFmt%"$Sep"}
		Get_Date_Part "$File" "+$DateFmt" "$DefaultFmt"
	else
		printf "%s" "${Out%"$Sep"}"
	fi
}

# Resolve_Path_Segment: resolve path segment
Resolve_Path_Segment() {
	local Req="${1,,}"
	local File="$2"
	local Res=""

	if [[ "$1" == *"'"* ]]; then
		Resolve_Joined_Tokens "$1" "$File"
		return
	fi

	case "$Req" in
	year) Res=$(Get_Date_Part "$File" '+%Y' '0000') ;;
	month) Res=$(Get_Date_Part "$File" '+%m' '00') ;;
	day) Res=$(Get_Date_Part "$File" '+%d' '00') ;;
	extension)
		Res=${File##*.}
		Res=${Res^^}
		;;
	mime) Res=${MIME^^} ;;
	mime-main) Res=${MIMEMain^^} ;;
	mime-sub) Res=${MIMESub^^} ;;

	size | format)
		if [[ "$MIMEMain" =~ ^(image|video)$ ]]; then
			local WxH Fmt
			WxH=$(Get_WxH "$File")
			Fmt=$(Get_WxH_Format "$WxH")

			if [[ "$WxH" == "0x0" || "$Fmt" == "ZERO/ZERO" ]]; then
				Res="ZERO"
			elif [[ "$Req" == size ]]; then
				Res="$WxH"
			else
				Res="$Fmt"
			fi
		else
			local S Label
			S=$(Get_File_Size "$File")
			Label=$(Get_Size_Label "$S" format)

			if [[ "$Req" == size ]]; then
				Res=$(Get_Size_Label "$S" dec)
			else
				Res=${Label//[0-9]/}
			fi
		fi
		;;

	created) Res=$(Get_File_Creation_Time "$File") ;;
	modified) Res=$(Get_File_Modification_Time "$File") ;;
	accessed) Res=$(Get_File_Access_Time "$File") ;;

	md5) Res=$(Get_MD5Sum "$File") ;;
	md5sum | shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum)
		Res=$(/usr/bin/$Req -b "$File" | cut -d' ' -f1)
		;;

	random) Res="${RANDOM}${RANDOM}" ;;
	*) Res="$1" ;;
	esac

	printf "%s" "$Res"
}

# Draw_Line: draw line
Draw_Line() {
	local W
	W=$(tput cols)
	printf '%*s\n' "$W" '' | tr ' ' "${1:-=}" | cut -c1-"$W"
}

# ===== MAIN =====

# Sort: sort
Sort() {
	((Current++))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		case "${Item,,}" in
		--pause=*)
			((Total[$Current]--))
			Pause=${Item#*=}
			;;
		--type=*)
			((Total[$Current]--))
			Type=${Item#*=}
			;;
		--mode=*)
			((Total[$Current]--))
			Mode=${Item#*=}
			;;
		--recursive)
			((Total[$Current]--))
			Recursive=yes
			;;
		--replace)
			((Total[$Current]--))
			Replace=yes
			;;
		--rename=*)
			((Total[$Current]--))
			Rename=${Item#*=}
			;;
		--title)
			((Total[$Current]--))
			Title=yes
			;;
		--extension=*)
			((Total[$Current]--))
			Extension=${Item#*=}
			;;
		--dirs=*)
			((Total[$Current]--))
			Dirs=${Item#*=}
			;;
		--subdirs=*)
			((Total[$Current]--))
			SubDirs=${Item#*=}
			;;
		*)
			((Counter[$Current]++))

			printf 'PROGRESS'
			for ((i = 1; i <= Current; i++)); do
				printf ' ~ [%d]=%d/%d' "$i" "${Counter[$i]}" "${Total[$i]}"
			done
			printf '\n'

			if [[ ! -e "$Item" ]]; then
				printf 'SKIP: Missing %s\n' "$Item"
				continue
			fi

			if [[ -L "$Item" ]]; then
				printf 'SKIP: Symlink %s\n' "$Item"
				continue
			fi

			if [[ -d "$Item" ]]; then
				Draw_Line '='

				if [[ "$Recursive" == yes ]]; then
					printf "$BOLDBLUE DIR:$YELLOW %s$RESET\n" "$Item"
					Draw_Line '>'
					Sort "$Item"/*

					if [[ "$Mode" == move ]]; then
						if rmdir "$Item" 2>/dev/null; then
							printf "$BLUE CLEANUP:$RESET %s\n" "$Item"
						else
							printf "$RED ERROR:$RESET Directory not empty: %s\n" "$Item"
						fi
					fi
				else
					printf "$RED DIR:$RESET Skipping!\n"
				fi

				Draw_Line '='
				continue
			fi

			if [[ -f "$Item" ]]; then
				Draw_Line '-'
				printf "$BOLDGREEN FILE:$YELLOW %s$RESET\n" "$Item"

				MIME=$(Get_MIME "$Item")
				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}

				printf "$YELLOW MIME:$RESET %s\n" "$MIME"

				if [[ -n "$Type" && "${MIME^^}" != *"${Type^^}"* ]]; then
					continue
				fi

				local D SD LOC NAME EXT NEWNAME COUNT BASENAME

				D=$(Resolve_Path_Segment "$Dirs" "$Item")
				SD=$([[ -n "$SubDirs" ]] && Resolve_Path_Segment "$SubDirs" "$Item")

				LOC='.'
				[[ -n "$D" ]] && LOC="${D^^}"
				[[ -n "$SD" ]] && LOC="$LOC/${SD^^}"

				printf "$YELLOW TARGET:$RESET %s\n" "$LOC"

				if [[ -n "$Title" ]]; then
					case "$MIMEMain" in
					application) NAME=$(Get_Doc_Title "$Item") ;;
					image) NAME=$(Get_Image_Meta "$Item") ;;
					audio) NAME=$(Get_Audio_Info "$Item") ;;
					video) NAME=$(Get_Video_Title "$Item") ;;
					esac
				fi

				[[ -z "$NAME" ]] && NAME=$(Get_File_Name "$Item")
				[[ -n "$Rename" ]] && NAME=$(Resolve_Path_Segment "$Rename" "$Item")

				EXT=$(Get_File_Ext "$Item")

				if [[ -n "$Extension" ]]; then
					EXT=$(Resolve_Path_Segment "$Extension" "$Item")
					EXT=${EXT,,}
					EXT=${EXT//\//.}
					EXT=${EXT// /_}
				fi

				NEWNAME="$NAME.$EXT"

				if [[ -z "$Replace" || -z "$Title" ]]; then
					COUNT=0
					BASENAME="$NAME"

					while [[ -e "$LOC/$NEWNAME" ]]; do
						((COUNT++))
						NEWNAME="$BASENAME-($COUNT).$EXT"
					done
				fi

				printf "$YELLOW NEW-NAME:$RESET %s\n" "$NEWNAME"

				if [[ -n "$Mode" ]]; then
					mkdir -p "$LOC"

					case "$Mode" in
					move)
						printf "$RED MOVE:$RESET %s\n" "$(mv -vf "$Item" "$LOC/$NEWNAME" 2>&1)"
						;;

					copy)
						printf "$RED COPY:$RESET %s\n" "$(cp -vf "$Item" "$LOC/$NEWNAME" 2>&1)"
						;;

					remove)
						printf "$RED REMOVE:$RESET %s\n" "$(trash-put -v "$Item" 2>&1)"
						;;
					esac
				else
					printf "$GREEN TEST:$RESET %s -> %s/%s\n" "$Item" "$LOC" "$NEWNAME"
				fi

				[[ -n "$Pause" ]] && sleep "$Pause"
				Draw_Line '-'
			fi
			;;
		esac
	done

	((Current--))
}

# ===== CLI =====

if (($# > 0)); then
	Sort "$@"
	printf "\n$GREEN---DONE---$RESET\n\n"
	IFS=$OIFS
	exit 0
fi

Draw_Line '━'

cat <<EOF
📂 Sort.sh v2.1

SYNTAX:
	Sort.sh [OPTIONS] [FILES/DIRS]

MODES:
	--mode=copy
	--mode=move
	--mode=remove

OPTIONS:
	--type=VALUE
	--recursive
	--replace
	--title
	--pause=SEC
	--dirs=OPT
	--subdirs=OPT
	--rename=OPT
	--extension=OPT

VALUES:
	year
	month
	day
	year'/'month
	year'/'month'/'day
	year'-'month'-'day
	year'_'month
	day'.'month'.'year
	created
	modified
	accessed
	extension
	mime
	mime-main
	mime-sub
	size
	format
	size'/'format
	format'/'size
	size'_'format
	format'-'size
	md5sum
	sha256sum
	random
EOF

Draw_Line '━'

echo "Thanks for using HEjder scripts!"
