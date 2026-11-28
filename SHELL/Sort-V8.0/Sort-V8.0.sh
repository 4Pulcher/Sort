#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V8.0.sh                                                      #
# Version : 8.0                                                               #
# Desc    : Source/target file organizer                                      #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

BOLD='\e[1m'
BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
RESET='\e[0m'

declare -A Required=(
	[date]='Linux Base'
	[file]='Linux Base'
	[stat]='Linux Base'
	[cp]='Linux Base'
	[mv]='Linux Base'
	[rm]='Linux Base'
	[rmdir]='Linux Base'
	[mkdir]='Linux Base'
	[dirname]='Linux Base'
	[md5sum]='Linux Base'
	[sha1sum]='Linux Base'
	[sha224sum]='Linux Base'
	[sha256sum]='Linux Base'
	[sha384sum]='Linux Base'
	[sha512sum]='Linux Base'
	[tput]='Linux Base'
	[realpath]='Linux Base'
)

for Key in "${!Required[@]}"; do
	if ! command -v "$Key" &>/dev/null; then
		printf '%bERROR:%b %s command is missing. Install: %s\n' "$RED" "$RESET" "$Key" "${Required[$Key]}"
		exit 10
	fi
done

OIFS=$IFS

Mode='dummy'
Recursive='no'
Replace='no'
Type=''
Pause=''
Dirs=''
SubDirs=''
Rename=''
Extension=''
Source=''
Target='.'

Current=0
declare -a Total Counter

# Break: break
function Break {
	IFS=$OIFS
	printf '\n%bWARNING:%b Interrupted by user.\n' "$YELLOW" "$RESET"
	exit 1
}

trap Break INT
trap 'IFS=$OIFS' EXIT
shopt -s dotglob

# Draw_Line: draw line
function Draw_Line {
	local W
	local S="${1:-=}"
	local L

	W=$(tput cols 2>/dev/null)
	W=${W:-80}

	printf -v L '%*s' "$W" ''
	printf '%s\n' "${L// /$S}"
}

# Trim: trim
function Trim {
	local V="$1"
	V="${V#${V%%[![:space:]]*}}"
	V="${V%${V##*[![:space:]]}}"
	printf '%s' "$V"
}

# Clean_Name: clean name
function Clean_Name {
	local V="$1"

	# Linux filenames may contain spaces and punctuation.
	# Only path separators are unsafe inside one filename segment.
	V=${V//\//_}
	V=${V//\/_/}

	while [[ "$V" == *__* ]]; do
		V=${V//__/_}
	done

	V=${V#_}
	V=${V%_}

	printf '%s' "$V"
}

# Clean_Path: clean path
function Clean_Path {
	local V="$1"
	local IFS='/'
	local Part
	local Out=''
	local -a Parts

	read -ra Parts <<<"$V"

	for Part in "${Parts[@]}"; do
		Part=$(Clean_Name "$Part")
		[ -z "$Part" ] && continue

		if [ -z "$Out" ]; then
			Out="$Part"
		else
			Out="$Out/$Part"
		fi
	done

	printf '%s' "$Out"
}

# Get_File_Name: get file name
function Get_File_Name {
	local B=${1##*/}

	# Hidden files like .bashrc should keep their name.
	if [[ "$B" == .* && "$B" != *.*.* ]]; then
		printf '%s' "$B"
	elif [[ "$B" == *.* ]]; then
		printf '%s' "${B%.*}"
	else
		printf '%s' "$B"
	fi
}

# Get_File_Ext: get file ext
function Get_File_Ext {
	local B=${1##*/}

	# Hidden files like .bashrc have no extension.
	if [[ "$B" == .* && "$B" != *.*.* ]]; then
		printf '%s' ''
	elif [[ "$B" == *.* ]]; then
		printf '%s' "${B##*.}"
	else
		printf '%s' ''
	fi
}

# Get_File_Size: get file size
function Get_File_Size {
	local S
	S=$(stat -c %s -- "$1" 2>/dev/null)
	printf '%s' "${S:-0}"
}

# Get_File_Birth: get file birth
function Get_File_Birth {
	local B
	B=$(stat -c %W -- "$1" 2>/dev/null)
	printf '%s' "${B:-0}"
}

# Get_File_Creation_Time: get file creation time
function Get_File_Creation_Time {
	stat -c %w -- "$1" 2>/dev/null
}

# Get_File_Access_Time: get file access time
function Get_File_Access_Time {
	stat -c %x -- "$1" 2>/dev/null
}

# Get_File_Modification_Time: get file modification time
function Get_File_Modification_Time {
	stat -c %y -- "$1" 2>/dev/null
}

# Get_Date_Part: get date part
function Get_Date_Part {
	local T
	T=$(Get_File_Birth "$1")

	if [ "$T" != '0' ] && [ -n "$T" ]; then
		date -d "@$T" "$2" 2>/dev/null || printf '%s' "$3"
	else
		printf '%s' "$3"
	fi
}

# Get_MIME: get mime
function Get_MIME {
	file -b --mime-type -- "$1" 2>/dev/null
}

# Get_Hash: get hash
function Get_Hash {
	local Tool="$1"
	local File="$2"
	local Hash

	read -r Hash _ < <("$Tool" -b -- "$File")
	printf '%s' "$Hash"
}

# Format_File_Size: format file size
function Format_File_Size {
	local Bytes="$1"
	local Mode="$2"
	local T="$Bytes"
	local N=0
	local Div=1000
	local -a Units

	[[ "$T" =~ ^[0-9]+$ ]] || T=0

	case "$Mode" in
	size)
		Units=('B' 'KB' 'MB' 'GB' 'TB' 'PB')
		;;
	size+format)
		Div=1024
		Units=('B' 'KiB' 'MiB' 'GiB' 'TiB' 'PiB')
		;;
	format | format+size)
		Units=('BYTE' 'KILO' 'MEGA' 'GIGA' 'TERA' 'PETA')
		;;
	esac

	while [ "$T" -ge "$Div" ] && [ "$N" -lt 5 ]; do
		T=$((T / Div))
		((N++))
	done

	case "$Mode" in
	size)
		printf '%s%s' "$T" "${Units[$N]}"
		;;
	size+format)
		printf '%s/%s' "$T" "${Units[$N]}"
		;;
	format)
		printf '%s' "${Units[$N]}"
		;;
	format+size)
		printf '%s/%s' "${Units[$N]}" "$T"
		;;
	esac
}

# Build_Metadata: build metadata
function Build_Metadata {
	File="$1"
	FileName=$(Get_File_Name "$File")
	FileExt=$(Get_File_Ext "$File")
	FileSize=$(Get_File_Size "$File")
	MIME=$(Get_MIME "$File")
	MIMEMain=${MIME%/*}
	MIMESub=${MIME#*/}
}

# Is_Dynamic_Value: is dynamic value
function Is_Dynamic_Value {
	local V="${1,,}"

	case "$V" in
	year | month | day | created | modified | accessed | extension | mime | mime-main | mime-sub | size | format | size+format | format+size | md5 | sha1sum | sha224sum | sha256sum | sha384sum | sha512sum | random)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

# Resolve_Value: resolve value
function Resolve_Value {
	local V="${1,,}"

	case "$V" in
	year)
		Get_Date_Part "$File" '+%Y' '0000'
		;;
	month)
		Get_Date_Part "$File" '+%m' '00'
		;;
	day)
		Get_Date_Part "$File" '+%d' '00'
		;;
	created)
		Get_File_Creation_Time "$File"
		;;
	modified)
		Get_File_Modification_Time "$File"
		;;
	accessed)
		Get_File_Access_Time "$File"
		;;
	extension)
		printf '%s' "${FileExt^^}"
		;;
	mime)
		printf '%s' "${MIME^^}"
		;;
	mime-main)
		printf '%s' "${MIMEMain^^}"
		;;
	mime-sub)
		printf '%s' "${MIMESub^^}"
		;;
	size)
		Format_File_Size "$FileSize" 'size'
		;;
	format)
		Format_File_Size "$FileSize" 'format'
		;;
	size+format)
		Format_File_Size "$FileSize" 'size+format'
		;;
	format+size)
		Format_File_Size "$FileSize" 'format+size'
		;;
	md5)
		Get_Hash md5sum "$File"
		;;
	sha1sum | sha224sum | sha256sum | sha384sum | sha512sum)
		Get_Hash "$V" "$File"
		;;
	random)
		printf '%s' "${RANDOM}${RANDOM}"
		;;
	*)
		printf '%s' "$1"
		;;
	esac
}

# Match_Dynamic_Value: match dynamic value
function Match_Dynamic_Value {
	local Text="${1,,}"
	local Match=''
	local Candidate

	# Longest names first, so size+format and format+size win over size/format.
	for Candidate in \
		sha256sum sha224sum sha384sum sha512sum \
		format+size size+format \
		mime-main mime-sub \
		modified accessed created \
		extension random format month sha1sum \
		year size mime md5 day; do
		if [[ "$Text" == "$Candidate"* ]]; then
			Match="$Candidate"
			break
		fi
	done

	printf '%s' "$Match"
}

# Resolve_Chain: resolve chain
function Resolve_Chain {
	local Expr="$1"
	local Context="${2:-path}"
	local Result=''
	local Rest
	local LowerRest
	local Match
	local Value
	local Char

	Expr=$(Trim "$Expr")
	Rest="$Expr"

	while [ -n "$Rest" ]; do
		LowerRest=${Rest,,}
		Match=$(Match_Dynamic_Value "$LowerRest")

		if [ -n "$Match" ]; then
			Value=$(Resolve_Value "$Match")

			case "$Context" in
			path)
				Value=$(Clean_Path "$Value")
				;;
			name)
				Value=$(Clean_Name "$Value")
				;;
			extension)
				Value=${Value,,}
				Value=${Value//\//.}
				Value=${Value// /_}
				Value=${Value#.}
				;;
			esac

			Result+="$Value"
			Rest="${Rest:${#Match}}"
		else
			Char="${Rest:0:1}"
			Result+="$Char"
			Rest="${Rest:1}"
		fi
	done

	case "$Context" in
	path)
		Clean_Path "$Result"
		;;
	name)
		Clean_Name "$Result"
		;;
	extension)
		Result=${Result,,}
		Result=${Result//\//.}
		Result=${Result// /_}
		Result=${Result#.}
		printf '%s' "$Result"
		;;
	esac
}

# Resolve_Flexible: resolve flexible
function Resolve_Flexible {
	local Expr="$1"
	local Context="${2:-path}"
	local Result=''
	local Segment
	local Value

	IFS='/' read -ra Segments <<<"$Expr"

	for Segment in "${Segments[@]}"; do
		Segment=$(Trim "$Segment")
		Value=$(Resolve_Chain "$Segment" "$Context")
		[ -z "$Value" ] && continue

		if [ -z "$Result" ]; then
			Result="$Value"
		else
			case "$Context" in
			path)
				Result="$Result/$Value"
				;;
			name)
				Result="${Result}_${Value}"
				;;
			extension)
				Result="${Result}.${Value}"
				;;
			esac
		fi
	done

	case "$Context" in
	path)
		Clean_Path "$Result"
		;;
	name)
		Clean_Name "$Result"
		;;
	extension)
		Result=${Result,,}
		Result=${Result//\//.}
		Result=${Result// /_}
		Result=${Result#.}
		printf '%s' "$Result"
		;;
	esac
}

# Build_Target_Path: build target path
function Build_Target_Path {
	local Loc="$Target"
	local D=''
	local SD=''
	local Name="$FileName"
	local Ext="$FileExt"

	[ -n "$Dirs" ] && D=$(Resolve_Flexible "$Dirs" 'path')
	[ -n "$SubDirs" ] && SD=$(Resolve_Flexible "$SubDirs" 'path')

	[ -n "$D" ] && Loc="$Loc/$D"
	[ -n "$SD" ] && Loc="$Loc/$SD"

	[ -n "$Rename" ] && Name=$(Resolve_Flexible "$Rename" 'name')
	[ -n "$Extension" ] && Ext=$(Resolve_Flexible "$Extension" 'extension')

	Name=$(Clean_Name "$Name")

	if [ -n "$Ext" ]; then
		NewName="$Name.$Ext"
	else
		NewName="$Name"
	fi

	FinalPath="$Loc/$NewName"

	if [ "$Replace" != 'yes' ]; then
		local C=0
		local Base="$Name"

		while [ -e "$FinalPath" ]; do
			((C++))
			if [ -n "$Ext" ]; then
				NewName="$Base-($C).$Ext"
			else
				NewName="$Base-($C)"
			fi
			FinalPath="$Loc/$NewName"
		done
	fi
}

# Execute_Action: execute action
function Execute_Action {
	local Src="$1"
	local Dst="$2"
	local Dir

	case "$Mode" in
	dummy)
		printf '%bTEST:%b %s -> %s
' "$GREEN" "$RESET" "$Src" "$Dst"
		return
		;;

	remove)
		printf '%bREMOVE:%b %s
' "$RED" "$RESET" "$Src"
		rm -f -- "$Src"
		return
		;;
	esac

	Dir=$(dirname -- "$Dst")
	mkdir -p -- "$Dir"

	if [ "$Replace" = 'yes' ] && [ -e "$Dst" ]; then
		# Prevent accidental self-overwrite.
		if [ "$(realpath -- "$Src" 2>/dev/null)" = "$(realpath -- "$Dst" 2>/dev/null)" ]; then
			printf '%bSKIP:%b Source and target are identical: %s
' "$YELLOW" "$RESET" "$Src"
			return
		fi

		rm -f -- "$Dst"
	fi

	case "$Mode" in
	copy)
		printf '%bCOPY:%b %s -> %s
' "$BLUE" "$RESET" "$Src" "$Dst"
		cp -f -- "$Src" "$Dst"
		;;

	move)
		printf '%bMOVE:%b %s -> %s
' "$YELLOW" "$RESET" "$Src" "$Dst"
		mv -f -- "$Src" "$Dst"
		;;

	*)
		printf '%bERROR:%b Unknown mode: %s
' "$RED" "$RESET" "$Mode"
		return 1
		;;
	esac
}

# Process_File: process file
function Process_File {
	local Item="$1"

	Build_Metadata "$Item"

	if [ -n "$Type" ] && [[ "${MIME,,}" != *"${Type,,}"* ]]; then
		return 0
	fi

	printf '%bFILE:%b %s
' "$GREEN" "$RESET" "$Item"
	printf '%bTYPE:%b %s
' "$YELLOW" "$RESET" "$MIME"

	if [ "$Mode" = 'remove' ]; then
		Execute_Action "$Item" ''
		[ -n "$Pause" ] && sleep "$Pause"
		return
	fi

	Build_Target_Path

	printf '%bTARGET:%b %s
' "$YELLOW" "$RESET" "$FinalPath"

	Execute_Action "$Item" "$FinalPath"

	[ -n "$Pause" ] && sleep "$Pause"
}

# Process_Path: process path
function Process_Path {
	local Item="$1"

	if [[ ! -e "$Item" ]]; then
		printf '%bSKIP:%b Missing: %s\n' "$YELLOW" "$RESET" "$Item"
		return 0
	fi

	if [[ -L "$Item" ]]; then
		printf '%bSKIP:%b Symlink: %s\n' "$YELLOW" "$RESET" "$Item"
		return 0
	fi

	if [[ -f "$Item" ]]; then
		Process_File "$Item"
		return
	fi

	if [[ -d "$Item" ]]; then
		if [ "$Recursive" != 'yes' ]; then
			printf '%bSKIP:%b Directory: %s\n' "$YELLOW" "$RESET" "$Item"
			return 0
		fi

		local Child

		for Child in "$Item"/*; do
			[ -e "$Child" ] || continue
			Process_Path "$Child"
		done

		if [ "$Mode" = 'move' ]; then
			rmdir -- "$Item" 2>/dev/null
		fi
	fi
}

# Confirm_Replace: confirm replace
function Confirm_Replace {
	local Answer

	printf '%bWARNING:%b Replace mode is enabled. Existing target files may be overwritten. Continue? [y/N]: ' "$YELLOW" "$RESET"

	read -r Answer

	case "$Answer" in
	y | Y)
		return 0
		;;
	*)
		printf '%bABORTED%b
' "$RED" "$RESET"
		exit 40
		;;
	esac
}

# Parse_Arguments: parse arguments
function Parse_Arguments {
	while [ $# -gt 0 ]; do
		case "${1,,}" in
		--mode=*)
			Mode=${1#*=}
			Mode=${Mode,,}
			;;
		--recursive)
			Recursive='yes'
			;;
		--replace)
			Replace='yes'
			;;
		--type=*)
			Type=${1#*=}
			Type=${Type,,}
			;;
		--pause=*)
			Pause=${1#*=}
			;;
		--dirs=*)
			Dirs=${1#*=}
			;;
		--subdirs=*)
			SubDirs=${1#*=}
			;;
		--rename=*)
			Rename=${1#*=}
			;;
		--extension=*)
			Extension=${1#*=}
			;;
		--source=*)
			Source=${1#*=}
			;;
		--target=*)
			Target=${1#*=}
			;;
		--help | -h)
			Show_Usage
			exit 0
			;;
		*)
			Inputs+=("$1")
			;;
		esac
		shift
	done
}

# Show_Usage: show usage
function Show_Usage {
	Draw_Line '='
	printf 'Sort.sh - Clean Fast File Organizer\n'
	Draw_Line '='

	cat <<'EOF'

SYNTAX:
    Sort.sh [OPTIONS] [FILES OR DIRECTORIES]

SOURCE / TARGET:
    --source=DIR          Source directory
    --target=DIR          Target directory, default: current directory

MODES:
    --mode=dummy          Show what would happen, no changes
    --mode=copy           Copy files
    --mode=move           Move files using mv
    --mode=remove         Remove files using rm -f

OPTIONS:
    --recursive           Process directories recursively
    --replace             Ask once before replacing existing target files
    --type=VALUE          Filter by MIME type
    --pause=SECONDS       Pause after each file

STRUCTURE:
    --dirs=VALUE          Main target directory
    --subdirs=VALUE       Secondary directory
    --rename=VALUE        Dynamic filename
    --extension=VALUE     Dynamic extension

DYNAMIC VALUES:
    year
    month
    day
    created
    modified
    accessed

    extension
    mime
    mime-main
    mime-sub

    size
    format
    size+format
    format+size

    md5
    sha1sum
    sha224sum
    sha256sum
    sha384sum
    sha512sum
    random

COMBINING VALUES:
    VALUE                 one value
    VALUE+VALUE           join values with /
    VALUE/VALUE           create directory levels

EXAMPLES:
    Sort.sh --mode=dummy --source=./2SORT --target=./SORTED --recursive --dirs=mime --subdirs=format+size --rename=md5 --extension=mime

    Sort.sh --mode=move --source=./Downloads --target=./Sorted --recursive --dirs=year/month --rename=sha256sum

    Sort.sh --mode=copy --type=image --dirs=mime-main --subdirs=extension ./Pictures/*

EOF

	Draw_Line '='
}

Inputs=()

if [ $# -eq 0 ]; then
	Show_Usage
	exit 0
fi

Parse_Arguments "$@"

if [ "$Replace" = 'yes' ] && [ "$Mode" != 'dummy' ]; then
	Confirm_Replace
fi

case "$Mode" in
dummy | copy | move | remove) ;;
*)
	printf '%bERROR:%b Invalid mode: %s\n' "$RED" "$RESET" "$Mode"
	exit 20
	;;
esac

[ -n "$Source" ] && Inputs+=("$Source")

if [ ${#Inputs[@]} -eq 0 ]; then
	printf '%bERROR:%b No input files or directories.\n' "$RED" "$RESET"
	exit 30
fi

Target=$(realpath -m -- "$Target" 2>/dev/null || printf '%s' "$Target")

printf 'Mode: %s\n' "$Mode"
printf 'Target: %s\n' "$Target"
[ -n "$Source" ] && printf 'Source: %s\n' "$Source"

for Item in "${Inputs[@]}"; do
	Process_Path "$Item"
done

printf '\n%bDONE%b\n' "$GREEN" "$RESET"

echo "Thanks for using HEjder scripts!"
