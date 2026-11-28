#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V4.3.sh                                                      #
# Version : 4.3                                                               #
# Desc    : CamelCase file organizer                                          #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder

# Function to handle interruptions
function handle_interrupt {
	IFS=$OIFS
	printf "HALTED!\n"
	exit
}

trap handle_interrupt INT

shopt -s dotglob

declare -A OPTIONS
OPTIONS=(
	["Pause"]=""
	["Probe"]="no"
	["Mode"]="none"
	["Recursive"]="no"
	["Replace"]="no"
	["Rename"]="original"
	["Extension"]="original"
	["Dirs"]="original"
	["SubDirs"]="none"
)

# Function to parse options
function parse_options {
	for Item in "$@"; do
		case ${Item,,} in
		"--pause="*)
			OPTIONS["Pause"]=${Item#*=}
			;;
		"--probe")
			OPTIONS["Probe"]="yes"
			;;
		"--copy")
			OPTIONS["Mode"]="copy"
			;;
		"--move")
			OPTIONS["Mode"]="move"
			;;
		"--remove")
			OPTIONS["Mode"]="remove"
			;;
		"--recursive")
			OPTIONS["Recursive"]="yes"
			;;
		"--replace")
			OPTIONS["Replace"]="yes"
			;;
		"--rename="*)
			OPTIONS["Rename"]=${Item#*=}
			;;
		"--extension="*)
			OPTIONS["Extension"]=${Item#*=}
			;;
		"--dirs="*)
			OPTIONS["Dirs"]=${Item#*=}
			;;
		"--subdirs="*)
			OPTIONS["SubDirs"]=${Item#*=}
			;;
		*)
			process_item "$Item"
			;;
		esac
	done
}

# Function to process each file or directory
function process_item {
	local Item="$1"

	if [ -d "$Item" ] && [ "${OPTIONS["Recursive"]}" == "yes" ]; then
		printf "DIR: $Item"
		for SubItem in "$Item"/*; do
			process_item "$SubItem"
		done
	elif [ -f "$Item" ]; then
		printf "FILE: $Item"
		handle_file "$Item"
	else
		printf "Error: unknown: $Item\n"
	fi
}

# Function to handle file operations
function handle_file {
	local File="$1"
	local OLD=$(sha256sum -b "$File" | cut -d ' ' -f 1)
	local NEW
	local Name
	local Ext
	local Dir
	local SubDir
	local Location
	local NewName

	if [ "${OPTIONS["Probe"]}" == "yes" ]; then
		mkdir -v -p "PROBE"
		while [ "$OLD" != "$NEW" ]; do
			cp -v -f "$File" "PROBE/${File##*/}"
			NEW=$(sha256sum -b "PROBE/${File##*/}" | cut -d ' ' -f 1)
		done
		File="PROBE/${File##*/}"
		[ "${OPTIONS["Mode"]}" == "move" ] && rm -v -f "$1"
	fi

	case "${OPTIONS["Rename"]}" in
	"sha256sum") Name=$OLD ;;
	*)
		Name=${File##*/}
		Name=${Name%%.*}
		;;
	esac

	case "${OPTIONS["Extension"]}" in
	"mime") Ext=$(file --mime-type "$File" | awk '{print $2}' | tr '/' '.') ;;
	"mime-main") Ext=$(file --mime-type "$File" | awk '{print $2}' | cut -d '/' -f 1) ;;
	"mime-sub") Ext=$(file --mime-type "$File" | awk '{print $2}' | cut -d '/' -f 2) ;;
	*) Ext=${File##*.} ;;
	esac

	case "${OPTIONS["Dirs"]}" in
	"mime") Dir=$(file --mime-type "$File" | awk '{print $2}' | tr '/' '.') ;;
	"mime-main") Dir=$(file --mime-type "$File" | awk '{print $2}' | cut -d '/' -f 1) ;;
	"mime-sub") Dir=$(file --mime-type "$File" | awk '{print $2}' | cut -d '/' -f 2) ;;
	"extension") Dir=$Ext ;;
	*) Dir=$(dirname "$File") ;;
	esac

	# Handling subdirectories based on the options
	if [ "${OPTIONS["SubDirs"]}" != "none" ]; then
		SubDir=$(calculate_subdir "$File")
	fi

	Location=$(construct_location "$Dir" "$SubDir")
	NewName="$Name.$Ext"
	if [ "${OPTIONS["Replace"]}" != "yes" ]; then
		NewName=$(handle_replace "$Location" "$NewName")
	fi

	perform_action "$File" "$Location/$NewName"
}

# Function to calculate subdirectories
function calculate_subdir {
	local File="$1"
	local MIMEMain=$(file --mime-type "$File" | awk '{print $2}' | cut -d '/' -f 1)
	local WxH

	if [ "$MIMEMain" == "image" ]; then
		WxH=$(identify -format "%wx%hXX" "$File" | tr -d '\n' | sed 's/XX/./')
	elif [ "$MIMEMain" == "video" ]; then
		WxH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$File" | tr -d '\n')
	else
		WxH=$(stat -c "%s" "$File" | tr -d '\n')
	fi

	echo "$WxH"
}

# Function to construct the final location for the file
function construct_location {
	local Dir="$1"
	local SubDir="$2"

	if [ -n "$Dir" ] && [ -n "$SubDir" ]; then
		echo "$Dir/$SubDir"
	elif [ -n "$Dir" ]; then
		echo "$Dir"
	elif [ -n "$SubDir" ]; then
		echo "$SubDir"
	else
		echo "$(pwd)"
	fi
}

# Function to handle file name replacement if necessary
function handle_replace {
	local Location="$1"
	local NewName="$2"
	local C=0

	while [ -e "$Location/$NewName" ]; do
		((C++))
		NewName="${NewName%.*}-($C).${NewName##*.}"
	done

	echo "$NewName"
}

# Function to perform the final action (copy, move, remove)
function perform_action {
	local Source="$1"
	local Target="$2"

	mkdir -v -p "$(dirname "$Target")"

	case "${OPTIONS["Mode"]}" in
	"move") mv -v -f "$Source" "$Target" ;;
	"copy") cp -v -f "$Source" "$Target" ;;
	"remove") [ -e "$Target" ] && rm -v -f "$Target" ;;
	*) echo "TARGET: $Source --> $Target" ;;
	esac

	[ -n "${OPTIONS["Pause"]}" ] && sleep "${OPTIONS["Pause"]}"
}

# Main script logic
if [ $# -gt 0 ]; then
	OIFS=$IFS
	IFS=$'\n\b'

	parse_options "$@"

	echo "DONE!"
	IFS=$OIFS
else
	cat <<EOF
Sort.sh
by HEjder

USAGE:

Sort.sh [--Copy|--Move] [--Recursive] [--Replace] [--Rename=(1)] [--Extension=(2)] [--Dirs=(3)] [--SubDirs=(4)] *

1)
  sha256sum
  * 'original'

2)
  mime
  mime-main
  mime-sub
  * 'original'

3)
  mime
  mime-main
  mime-sub
  extension
  * 'original'

4)
  size
  format
  format+size
  * 'none'
EOF
fi

echo "Thanks for using HEjder scripts!"
