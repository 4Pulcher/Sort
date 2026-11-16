#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V14.1.sh                                                     #
# Version : 14.1                                                              #
# Desc    : Safe Transport Engine                                             #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# ============================================================
# Sort.sh
# Metadata-Driven File Organization & Safe Transport Engine
# ============================================================

# ============================================================
# UI COLORS
# ============================================================

BOLD='\e[1m]'
DIM='\e[2m]'

COLOR_INFO='\e[36m]'
COLOR_SUCCESS='\e[32m]'
COLOR_WARNING='\e[33m]'
COLOR_ERROR='\e[31m]'
COLOR_PATH='\e[37m]'
COLOR_LABEL='\e[94m]'

RESET='\e[0m]'

# ============================================================
# REQUIREMENTS
# ============================================================

Required=(
	file
	stat
	cp
	rm
	sha256sum
	md5sum
	ffprobe
)

for CMD in "${Required[@]}"; do

	if ! command -v "$CMD" &>/dev/null; then

		printf '%bERROR:%b Missing command: %s\n' "$RED" "$RESET" "$CMD"
		exit 1

	fi

done

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================

CFG_MODE='dummy'
CFG_RECURSIVE='no'
CFG_REPLACE='no'
CFG_PROBE='no'
CFG_TITLE='no'
CFG_TYPE=''
CFG_PAUSE=''
CFG_DIRS=''
CFG_SUBDIRS=''
CFG_RENAME=''
CFG_EXTENSION=''

# ============================================================
# SAFETY
# ============================================================

OIFS=$IFS

# Cleanup: cleanup
function Cleanup {
	IFS=$OIFS
}

# Break: break
function Break {
	Cleanup
	printf '\nInterrupted by user\n'
	exit 1
}

trap Break INT
trap Cleanup EXIT

shopt -s dotglob

# ============================================================
# HELPERS
# ============================================================

# Draw_Line: draw line
function Draw_Line {

	local Width
	local Char
	local Line

	Width=$(tput cols)
	Char="${1:-=}"

	printf -v Line '%*s' "$Width" ''

	printf '%s\n' "${Line// /$Char}"
}

# Get_File_Name: get file name
function Get_File_Name {

	local Base

	Base=${1##*/}

	printf '%s' "${Base%.*}"
}

# Get_File_Ext: get file ext
function Get_File_Ext {
	printf '%s' "${1##*.}"
}

# Get_File_Size: get file size
function Get_File_Size {

	local Size

	Size=$(stat -c %s "$1" 2>/dev/null)

	printf '%s' "${Size:-0}"
}

# Get_MD5Sum: get md5 sum
function Get_MD5Sum {

	local Hash

	read -r Hash _ < <(md5sum -b "$1")

	printf '%s' "$Hash"
}

# Get_SHA256Sum: get sha256 sum
function Get_SHA256Sum {

	local Hash

	read -r Hash _ < <(sha256sum -b "$1")

	printf '%s' "$Hash"
}

# Get_MIME: get mime
function Get_MIME {

	file -b --mime-type "$1" 2>/dev/null
}

# Get_File_Birth: get file birth
function Get_File_Birth {

	local Birth

	Birth=$(stat -c %W "$1" 2>/dev/null)

	printf '%s' "${Birth:-0}"
}

# Get_Date_Part: get date part
function Get_Date_Part {

	local Timestamp

	Timestamp=$(Get_File_Birth "$1")

	if [ "$Timestamp" != '0' ]; then
		date -d "@$Timestamp" "$2" 2>/dev/null
	else
		printf '%s' "$3"
	fi
}

# Get_Image_WxH: get image wx h
function Get_Image_WxH {

	ffprobe \
		-v error \
		-select_streams v:0 \
		-show_entries stream=width,height \
		-of csv=s=x:p=0 \
		"$1" 2>/dev/null
}

# Get_WxH_Format: get wx h format
function Get_WxH_Format {

	[[ ! "$1" =~ [0-9]+x[0-9]+ ]] && {
		printf 'ZERO/UNKNOWN'
		return
	}

	local W=${1%%x*}
	local H=${1##*x}

	local MAX=$W

	[ "$H" -gt "$W" ] && MAX=$H

	local SIZE='HUGE'

	if [ "$MAX" -lt 512 ]; then
		SIZE='SMALLER'
	elif [ "$MAX" -lt 1024 ]; then
		SIZE='SMALL'
	elif [ "$MAX" -lt 2048 ]; then
		SIZE='MEDIUM'
	elif [ "$MAX" -lt 4096 ]; then
		SIZE='BIG'
	elif [ "$MAX" -lt 8096 ]; then
		SIZE='BIGGER'
	fi

	local ASPECT='SQUARE'

	if [ "$W" -gt "$H" ]; then
		ASPECT='WIDE'
	elif [ "$W" -lt "$H" ]; then
		ASPECT='HIGH'
	fi

	printf '%s/%s' "$SIZE" "$ASPECT"
}

# ============================================================
# METADATA CACHE
# ============================================================

# Build_Metadata: build metadata
function Build_Metadata {

	FILE_PATH="$1"

	FILE_NAME=$(Get_File_Name "$FILE_PATH")
	FILE_EXT=$(Get_File_Ext "$FILE_PATH")
	FILE_SIZE=$(Get_File_Size "$FILE_PATH")

	FILE_MIME=$(Get_MIME "$FILE_PATH")
	FILE_MIME_MAIN=${FILE_MIME%/*}
	FILE_MIME_SUB=${FILE_MIME#*/}

	FILE_WXH=''
	FILE_FORMAT=''

	if [[ "$FILE_MIME_MAIN" == 'image' || "$FILE_MIME_MAIN" == 'video' ]]; then

		FILE_WXH=$(Get_Image_WxH "$FILE_PATH")
		FILE_FORMAT=$(Get_WxH_Format "$FILE_WXH")

	fi
}

# ============================================================
# PATH RESOLUTION
# ============================================================

# Resolve_Path_Segment: resolve path segment
function Resolve_Path_Segment {

	local Req="${1,,}"

	case "$Req" in

	year)
		Get_Date_Part "$FILE_PATH" '+%Y' '0000'
		;;

	month)
		Get_Date_Part "$FILE_PATH" '+%m' '00'
		;;

	day)
		Get_Date_Part "$FILE_PATH" '+%d' '00'
		;;

	year+month)
		Get_Date_Part "$FILE_PATH" '+%Y/%m' '0000/00'
		;;

	year+month+day)
		Get_Date_Part "$FILE_PATH" '+%Y/%m/%d' '0000/00/00'
		;;

	extension)
		printf '%s' "${FILE_EXT^^}"
		;;

	mime)
		printf '%s' "${FILE_MIME^^}"
		;;

	mime-main)
		printf '%s' "${FILE_MIME_MAIN^^}"
		;;

	mime-sub)
		printf '%s' "${FILE_MIME_SUB^^}"
		;;

	size)
		printf '%s' "$FILE_SIZE"
		;;

	format)
		printf '%s' "$FILE_FORMAT"
		;;

	md5)
		Get_MD5Sum "$FILE_PATH"
		;;

	sha256sum)
		Get_SHA256Sum "$FILE_PATH"
		;;

	random)
		printf '%s' "${RANDOM}${RANDOM}"
		;;

	*)
		printf '%s' "$1"
		;;

	esac
}

# ============================================================
# VERIFY FILE
# ============================================================

# Verify_File: verify file
function Verify_File {

	local SRC="$1"
	local DST="$2"

	local SRC_SIZE
	local DST_SIZE

	SRC_SIZE=$(Get_File_Size "$SRC")
	DST_SIZE=$(Get_File_Size "$DST")

	if [ "$SRC_SIZE" != "$DST_SIZE" ]; then
		return 1
	fi

	sync

	local SRC_MD5
	local DST_MD5

	SRC_MD5=$(Get_MD5Sum "$SRC")
	DST_MD5=$(Get_MD5Sum "$DST")

	[[ "$SRC_MD5" == "$DST_MD5" ]]
}

# ============================================================
# COPY FILE
# ============================================================

# Copy_File: copy file
function Copy_File {

	local SRC="$1"
	local DST="$2"

	cp -f -- "$SRC" "$DST"
}

# ============================================================
# SAFE MOVE
# ============================================================

# Safe_Move: safe move
function Safe_Move {

	local SRC="$1"
	local DST="$2"

	Copy_File "$SRC" "$DST" || return 1

	if [ "$CFG_PROBE" = 'yes' ]; then

		Verify_File "$SRC" "$DST" || {

			printf '%bVERIFY FAILED:%b %s\n' "$RED" "$RESET" "$SRC"

			rm -f -- "$DST"

			return 1
		}

	fi

	rm -f -- "$SRC"
}

# ============================================================
# EXECUTION
# ============================================================

# Execute_Action: execute action
function Execute_Action {

	local SRC="$1"
	local DST="$2"

	mkdir -p -- "$(dirname "$DST")"

	case "$CFG_MODE" in

	dummy)

		printf '%bTEST:%b %s -> %s\n' \
			"$GREEN" \
			"$RESET" \
			"$SRC" \
			"$DST"
		;;

	copy)

		printf '%bCOPY:%b %s\n' \
			"$BLUE" \
			"$RESET" \
			"$SRC"

		Copy_File "$SRC" "$DST" || return 1

		if [ "$CFG_PROBE" = 'yes' ]; then

			Verify_File "$SRC" "$DST" || {

				printf '%bVERIFY FAILED:%b %s\n' \
					"$RED" \
					"$RESET" \
					"$SRC"

				return 1
			}

		fi
		;;

	move)

		printf '%bMOVE:%b %s\n' \
			"$YELLOW" \
			"$RESET" \
			"$SRC"

		Safe_Move "$SRC" "$DST"
		;;

	remove)

		printf '%bREMOVE:%b %s\n' \
			"$RED" \
			"$RESET" \
			"$SRC"

		rm -f -- "$SRC"
		;;

	esac
}

# ============================================================
# PROCESS FILE
# ============================================================

# Process_File: process file
function Process_File {

	local Item="$1"

	Build_Metadata "$Item"

	if [ -n "$CFG_TYPE" ]; then

		[[ "${FILE_MIME,,}" == *"${CFG_TYPE,,}"* ]] || return

	fi

	local DIRS='.'
	local SUBDIRS=''

	[ -n "$CFG_DIRS" ] && DIRS=$(Resolve_Path_Segment "$CFG_DIRS")
	[ -n "$CFG_SUBDIRS" ] && SUBDIRS=$(Resolve_Path_Segment "$CFG_SUBDIRS")

	local TARGET="$DIRS"

	[ -n "$SUBDIRS" ] && TARGET="$TARGET/$SUBDIRS"

	local NAME="$FILE_NAME"

	[ -n "$CFG_RENAME" ] && NAME=$(Resolve_Path_Segment "$CFG_RENAME")

	local EXT="$FILE_EXT"

	if [ -n "$CFG_EXTENSION" ]; then

		EXT=$(Resolve_Path_Segment "$CFG_EXTENSION")

		EXT=${EXT,,}
		EXT=${EXT//\//.}
		EXT=${EXT// /_}

	fi

	local NEW_NAME="$NAME.$EXT"
	local FINAL_PATH="$TARGET/$NEW_NAME"

	if [ "$CFG_REPLACE" != 'yes' ]; then

		local N=1

		while [ -e "$FINAL_PATH" ]; do

			FINAL_PATH="$TARGET/${NAME}-($N).$EXT"

			((N++))

		done

	fi

	printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"
	printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$FILE_MIME"
	printf '%bTARGET:%b %s\n' "$YELLOW" "$RESET" "$FINAL_PATH"

	Execute_Action "$Item" "$FINAL_PATH"

	[ -n "$CFG_PAUSE" ] && sleep "$CFG_PAUSE"
}

# ============================================================
# DIRECTORY PROCESSING
# ============================================================

# Process_Path: process path
function Process_Path {

	local Item="$1"

	if [[ ! -e "$Item" ]]; then

		printf 'SKIP: Missing %s\n' "$Item"
		return

	fi

	if [[ -L "$Item" ]]; then

		printf 'SKIP: Symlink %s\n' "$Item"
		return

	fi

	if [[ -f "$Item" ]]; then

		Process_File "$Item"
		return

	fi

	if [[ -d "$Item" ]]; then

		[ "$CFG_RECURSIVE" != 'yes' ] && return

		local Child

		for Child in "$Item"/*; do

			[ -e "$Child" ] || continue

			Process_Path "$Child"

		done

	fi
}

# ============================================================
# ARGUMENT PARSER
# ============================================================

# Parse_Arguments: parse arguments
function Parse_Arguments {

	while [ $# -gt 0 ]; do

		case "${1,,}" in

		--mode=*)
			CFG_MODE=${1#*=}
			CFG_MODE=${CFG_MODE,,}
			;;

		--recursive)
			CFG_RECURSIVE='yes'
			;;

		--replace)
			CFG_REPLACE='yes'
			;;

		--probe)
			CFG_PROBE='yes'
			;;

		--title)
			CFG_TITLE='yes'
			;;

		--type=*)
			CFG_TYPE=${1#*=}
			CFG_TYPE=${CFG_TYPE,,}
			;;

		--pause=*)
			CFG_PAUSE=${1#*=}
			;;

		--dirs=*)
			CFG_DIRS=${1#*=}
			CFG_DIRS=${CFG_DIRS,,}
			;;

		--subdirs=*)
			CFG_SUBDIRS=${1#*=}
			CFG_SUBDIRS=${CFG_SUBDIRS,,}
			;;

		--rename=*)
			CFG_RENAME=${1#*=}
			CFG_RENAME=${CFG_RENAME,,}
			;;

		--extension=*)
			CFG_EXTENSION=${1#*=}
			CFG_EXTENSION=${CFG_EXTENSION,,}
			;;

		*)
			INPUTS+=("$1")
			;;

		esac

		shift

	done
}

# ============================================================
# MAIN
# ============================================================

if [ $# -eq 0 ]; then

	Draw_Line '='

	printf 'Sort.sh\n'
	printf 'Metadata-Driven File Organization Engine\n'

	Draw_Line '='

	exit 0

fi

INPUTS=()

Parse_Arguments "$@"

for Item in "${INPUTS[@]}"; do
	Process_Path "$Item"
done

printf '\n%bDONE%b\n' "$GREEN" "$RESET"

echo "Thanks for using HEjder scripts!"
