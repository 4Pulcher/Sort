#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V4.5.sh                                                      #
# Version : 4.5                                                               #
# Desc    : CamelCase file organizer                                          #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# by HEjder

# Function to handle Ctrl+C (SIGINT)
function Break {
	IFS=$OIFS
	printf "\n"
	exit
}

# Trap Ctrl+C
trap Break INT

# Enable dotglob for wildcard matching
shopt -s dotglob

# Function to get SHA256 sum of a file
function Get_SHA256Sum {
	if command -v sha256sum >/dev/null 2>&1; then
		local SUM=$(sha256sum -b "$1" | tr -d '\n')
		printf "%b" ${SUM%% *}
	else
		echo "Error: sha256sum command not found."
		return 1
	fi
}

# Function to get MIME type of a file
function Get_MIME {
	if command -v file >/dev/null 2>&1; then
		local MIME=$(file --mime-type "$1" | tr -d '\n')
		printf "%b" ${MIME##* }
	else
		echo "Error: file command not found."
		return 1
	fi
}

# Function to get file name without extension
function Get_File_Name {
	local Name=${1##*/}
	printf "%b" ${Name%%.*}
}

# Function to get file extension
function Get_File_Extension {
	local Extension=${1##*/}
	printf "%b" ${Extension#*.}
}

# Function to get file size in bytes
function Get_File_Size {
	if command -v stat >/dev/null 2>&1; then
		printf $(stat -c "%s" "$1" | tr -d '\n')
	else
		echo "Error: stat command not found."
		return 1
	fi
}

# Function to get image dimensions (width x height)
function Get_Image_WxH {
	if command -v identify >/dev/null 2>&1; then
		local WxH=$(identify -format "%wx%h-" "$1" | tr -d '\n')
		printf "%b" ${WxH%%-*}
	else
		echo "Error: identify command not found."
		return 1
	fi
}

# Function to get video dimensions (width x height)
function Get_Video_WxH {
	if command -v ffprobe >/dev/null 2>&1; then
		printf $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" | tr -d '\n')
	else
		echo "Error: ffprobe command not found."
		return 1
	fi
}

# Function to sort files and directories
function Sort {
	local Total=$#
	local Current=0
	local Options=()
	local Files=()

	# Parse options and files
	while [[ $# -gt 0 ]]; do
		case "${1,,}" in
		"--pause="*)
			Options+=("--pause=${1#*=}")
			shift
			;;
		"--probe")
			Options+=("--probe")
			shift
			;;
		"--copy")
			Options+=("--copy")
			shift
			;;
		"--move")
			Options+=("--move")
			shift
			;;
		"--remove")
			Options+=("--remove")
			shift
			;;
		"--recursive")
			Options+=("--recursive")
			shift
			;;
		"--replace")
			Options+=("--replace")
			shift
			;;
		"--rename="*)
			Options+=("--rename=${1#*=}")
			shift
			;;
		"--extension="*)
			Options+=("--extension=${1#*=}")
			shift
			;;
		"--dirs="*)
			Options+=("--dirs=${1#*=}")
			shift
			;;
		"--subdirs="*)
			Options+=("--subdirs=${1#*=}")
			shift
			;;
		*)
			# Store SHA256 sum and file name in Files array
			local SHA256=$(Get_SHA256Sum "$1")
			Files+=("sha256sum=$SHA256 file-name=$1")
			shift
			;;
		esac
	done

	# Process options
	local Probe=false
	local Mode="dummy"
	local Recursive=false
	local Replace=false
	local Rename="original"
	local Extension="original"
	local Dirs="original"
	local SubDirs="none"
	local Pause=""

	for Option in "${Options[@]}"; do
		case "${Option,,}" in
		"--pause="*)
			Pause="${Option#*=}"
			echo "Pause: $Pause"
			;;
		"--probe")
			Probe=true
			echo "Probe: $Probe"
			;;
		"--copy")
			Mode="copy"
			echo "Mode: $Mode"
			;;
		"--move")
			Mode="move"
			echo "Mode: $Mode"
			;;
		"--remove")
			Mode="remove"
			echo "Mode: $Mode"
			;;
		"--recursive")
			Recursive=true
			echo "Recursive: $Recursive"
			;;
		"--replace")
			Replace=true
			echo "Replace: $Replace"
			;;
		"--rename="*)
			Rename="${Option#*=}"
			echo "Rename: $Rename"
			;;
		"--extension="*)
			Extension="${Option#*=}"
			echo "Extension: $Extension"
			;;
		"--dirs="*)
			Dirs="${Option#*=}"
			echo "Directories: $Dirs"
			;;
		"--subdirs="*)
			SubDirs="${Option#*=}"
			echo "Sub-Directories: $SubDirs"
			;;
		esac
	done

	# Process files
	for ((Current = 0; Current < ${#Files[@]}; Current++)); do
		local Item="${Files[$Current]}"
		echo "COUNT: $((Current + 1))/$Total"

		# Extract SHA256 sum and file name from the array element
		local SHA256="${Item%% *}"
		local FileName="${Item##* }"
		SHA256="${SHA256#*=}"
		FileName="${FileName#*=}"

		if [[ -d "$FileName" && "$Recursive" == "true" ]]; then
			echo "DIR: $FileName"
			Sort "${Options[@]}" "$FileName"/*
		elif [[ -f "$FileName" ]]; then
			echo "FILE -->"
			echo "SOURCE: $FileName"

			local OLD=$SHA256

			# PROBE
			if [[ "$Probe" == "true" ]]; then
				echo "PROBE: $(mkdir -v -p "PROBE")"

				if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
					local NEW=""
					echo "PROBE: $(while [[ "$OLD" != "$NEW" ]]; do
						cp -v -f "$FileName" "PROBE/${FileName##*/}"
						NEW=$(Get_SHA256Sum "PROBE/${FileName##*/}")
					done)"

					if [[ "$Mode" == "move" ]]; then
						echo "PROBE: $(rm -v -f "$FileName")\n"
					fi

					FileName="PROBE/${FileName##*/}"
				fi
			fi

			# VARIABLES
			printf "VARIABLES -->\n"
			local MIME=$(Get_MIME "$FileName")
			local MIMEMain=${MIME%/*}
			local MIMESub=${MIME#*/}

			# NAMES
			local Name=""
			case "${Rename,,}" in
			"sha256sum")
				Name=$OLD
				;;
			"name")
				Name=$(Get_File_Name "$FileName")
				;;
			esac

			echo "NAME: $Name"

			# EXTENSIONS
			local Ext=""
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
			"name")
				Ext=$(Get_File_Extension "$FileName")
				;;
			esac

			echo "EXTENSION: $Ext"

			# DIRECTORIES
			local Dir=""
			if [[ "$Dirs" != "original" ]]; then
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
					if [[ "$Ext" == "" ]]; then
						Dir=$(Get_File_Extension "$FileName")
					else
						Dir=${Ext^^}
					fi
					;;
				esac

				echo "DIRECTORY: $Dir"
			fi

			# SUB-DIRECTORIES
			local SubDir=""
			if [[ "$SubDirs" != "none" ]]; then
				local WxH=""
				case "${MIMEMain,,}" in
				"image")
					WxH=$(Get_Image_WxH "$FileName")
					;;
				"video")
					WxH=$(Get_Video_WxH "$FileName")
					;;
				esac

				echo "WIDTH x HEIGHT: $WxH"

				local W=${WxH%%x*}
				local H=${WxH##*x}

				local FileSize=""
				if [[ "$WxH" == "" || "$W" == "" || "$H" == "" ]]; then
					FileSize="0x0"
				else
					FileSize=$WxH
				fi

				local FileFormat=$(
					if [[ "$W" -lt "32" && "$H" -lt "32" ]]; then
						printf "TINY"
					elif [[ "$W" -lt "512" && "$H" -lt "512" ]]; then
						printf "SMALLER"
					elif [[ "$W" -lt "1024" && "$H" -lt "1024" ]]; then
						printf "SMALL"
					elif [[ "$W" -lt "2048" && "$H" -lt "2048" ]]; then
						printf "MEDIUM"
					elif [[ "$W" -lt "4096" && "$H" -lt "4096" ]]; then
						printf "BIG"
					elif [[ "$W" -lt "8192" && "$H" -lt "8192" ]]; then
						printf "BIGGER"
					elif [[ "$W" -lt "16384" && "$H" -lt "16384" ]]; then
						printf "SUPER"
					else
						printf "HUGE"
					fi

					printf "/"

					if [[ "$W" -gt "$H" ]]; then
						printf "WIDE"
					elif [[ "$W" -lt "$H" ]]; then
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
				esac
			else
				local FileSize=$(Get_File_Size "$FileName")

				case "${SubDirs,,}" in
				"size")
					SubDir=$FileSize
					;;
				"format")
					local Format=("Byte" "KiloByte" "MegaByte" "GigaByte" "TerraByte" "PetaByte" "ExaByte" "ZettaByte" "YottaByte" "RonnaByte" "QuettaByte")

					local Tmp=$FileSize
					local N=0
					while [[ "$Tmp" -gt "999" ]]; do
						((N++))
						Tmp=$(($Tmp / 1000))
					done

					SubDir="${Format[$N]}"
					;;
				"size+format")
					local Format=("B" "KB" "MB" "GB" "TB" "PB" "EB" "ZB" "YB" "RB" "QB")

					local Tmp=$FileSize
					local N=0
					while [[ "$Tmp" -gt "999" ]]; do
						((N++))
						Tmp=$(($Tmp / 1000))
					done

					SubDir="$Tmp ${Format[$N]}"
					;;
				esac
			fi

			echo "SUB-DIRECTORY: $SubDir"

			# ACTIONS
			echo "ACTIONS -->"

			# PRE-ACTION
			local Location=""
			if [[ "$Dir" != "" && "$SubDir" != "" ]]; then
				Location="${Dir^^}/${SubDir^^}"
			elif [[ "$Dir" != "" ]]; then
				Location="${Dir^^}"
			elif [[ "$SubDir" != "" ]]; then
				Location="${SubDir^^}"
			else
				Location=$(pwd)
			fi

			local NewName="$Name.$Ext"

			if [[ "$Replace" == "false" ]]; then
				local C=0
				while [[ -e "$Location/$NewName" ]]; do
					((C++))
					NewName="$Name-($C).$Ext"
				done
			fi

			# ACTION
			if [[ "$Probe" == "true" || "$Mode" == "move" ]]; then
				echo "MKDIR: $(mkdir -v -p "$Location")"
				echo "MOVE: $(mv -v -f "$FileName" "$Location/$NewName")"
			elif [[ "$Mode" == "copy" ]]; then
				echo "MKDIR: $(mkdir -v -p "$Location")"
				echo "COPY: $(cp -v -f "$FileName" "$Location/$NewName")"
			elif [[ "$Mode" == "remove" ]]; then
				echo "REMOVE: $(if [[ -e "$Location/$NewName" ]]; then rm -v -f "$Location/$NewName"; else printf "No such file!"; fi)"
			else
				echo "DUMMY: $FileName --> $Location/$NewName"
			fi

			# PAUSE
			if [[ "$Pause" != "" ]]; then
				echo "PAUSE: $Pause"
				sleep $Pause
			fi

			echo "<---DONE"
		else
			echo "ERROR: $FileName"
		fi
	done
}

if [[ $# -gt 0 ]]; then
	OIFS=$IFS
	IFS=$'\n\b'

	Sort "$@"

	IFS=$OIFS
else
	cat <<EOF
Sort.sh
by HEjder

Version: 1.0

USAGE:

Sort.sh [--Probe] [--Copy|--Move|--Remove] [--Recursive] [--Replace] [--Rename=(1)] [--Extension=(2)] [--Dirs=(3)] [--SubDirs=(4)] [--Pause=(seconds)] List

(1)
sha256sum

(2)
mime
mime-main
mime-sub
name

(3)
mime
mime-main
mime-sub
extension

(4)
size
format
format+size

List: List of directories or files!
EOF
fi

echo "Thanks for using HEjder scripts!"
