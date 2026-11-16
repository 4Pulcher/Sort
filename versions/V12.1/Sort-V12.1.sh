#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V12.1.sh                                                     #
# Version : 12.1                                                              #
# Desc    : Threaded file organizer with logging                              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# ==============================================================================
# Sort.sh v5 (Threadded and Logging) - Media-Intelligent File Organizer with Threading & Logging
# Developed by: HEjder
# ==============================================================================

# ==============================================================================
# 1. TERMINAL COLORS & LOGGING SETUP
# ==============================================================================
# Base ANSI colors
_BOLD='\e[1m'
_BLUE='\e[34m'
_GREEN='\e[32m'
_RED='\e[31m'
_YELLOW='\e[33m'
_RESET='\e[0m'

# Active color variables (toggled off if --colors is not requested)
BOLD=""
BLUE=""
GREEN=""
RED=""
YELLOW=""
RESET=""

# Logging flags & variables
ENABLE_LOG="no"
LOG_FILE=""

# ==============================================================================
# 2. SYSTEM DEPENDENCY CHECK
# ==============================================================================
declare -A Required=(
	[file]="file"
	[stat]="coreutils"
	[cp]="coreutils"
	[mv]="coreutils"
	[rm]="coreutils"
	[mkdir]="coreutils"
	[rmdir]="coreutils"
	[realpath]="coreutils"
	[sha256sum]="coreutils"
	[md5sum]="coreutils"
	[cut]="coreutils"
	[head]="coreutils"
	[tr]="coreutils"
	[date]="coreutils"
	[timeout]="coreutils"
	[sleep]="coreutils"
	[grep]="grep"
	[sed]="sed"
	[ffprobe]="ffmpeg"
	[identify]="imagemagick"
	[tput]="ncurses-bin / ncurses"
)

Errors=0
for Key in "${!Required[@]}"; do
	if ! command -v "$Key" >/dev/null 2>&1; then
		((Errors += 1))
	fi
done

if ((Errors > 0)); then
	printf 'ERROR: %d required command(s) missing; cannot continue.\n' "$Errors"
	exit 1
fi

# ==============================================================================
# 3. GLOBAL CONFIGURATION & SIGNAL TRAPS
# ==============================================================================
OIFS=$IFS
Mode=""

Type=""
Recursive="no"
Dirs=""
SubDirs=""
Rename=""
Title=""
Extension=""
Replace="no"
Pause=""
MAX_JOBS=4
Compare="no"

declare -a Total Counter
Current=0

# Exit: exit
Exit() {
	local Status=${1:-0}
	trap - EXIT
	wait
	IFS=$OIFS
	exit "$Status"
}

# Break: break
Break() {
	Exit 130
}

trap 'Exit $?' EXIT
trap Break INT

shopt -s dotglob nullglob

# ==============================================================================
# 4. LOGGING & PRINT ROUTINE
# ==============================================================================
# Centralized output function that prints to screen and optionally tees to log.
Log_Print() {
	local FormatStr=$1
	shift

	# Print to stdout (screen)
	# shellcheck disable=SC2059
	printf "$FormatStr" "$@"

	# If --log is enabled, strip ANSI codes and append to logfile
	if [[ "$ENABLE_LOG" == "yes" && -n "$LOG_FILE" ]]; then
		# shellcheck disable=SC2059
		local CleanMsg
		CleanMsg=$(printf "$FormatStr" "$@" | sed -r 's/\x1B\[[0-9;]*[mK]//g')
		printf '%s' "$CleanMsg" >>"$LOG_FILE"
	fi
}

# ==============================================================================
# 5. FILE ATTRIBUTE & CHECKSUM HELPERS
# ==============================================================================
Get_MD5Sum() {
	local File=$1
	md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1
}

# Get_SHA_Keys: get sha keys
Get_SHA_Keys() {
	local CommandName=$1
	local File=$2
	[[ ! -x "/usr/bin/$CommandName" ]] && {
		printf 'ERROR'
		return 1
	}
	/usr/bin/"$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1
}

# Get_SHA256Sum: get sha256 sum
Get_SHA256Sum() {
	local File=$1
	sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1
}

# Get_MIME: get mime
Get_MIME() {
	local File=$1
	file -b --mime-type -- "$File" 2>/dev/null
}

# Get_File_Name: get file name
Get_File_Name() {
	local Name=${1##*/}
	printf '%s' "${Name%.*}"
}

# Get_File_Ext: get file ext
Get_File_Ext() {
	local BaseName=${1##*/}
	if [[ "$BaseName" != *.* || ("$BaseName" == .* && "$BaseName" != *.*.*) ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}

# Get_File_Size: get file size
Get_File_Size() {
	stat -c '%s' -- "$1" 2>/dev/null
}

# Get_File_Birth: get file birth
Get_File_Birth() {
	stat -c '%W' -- "$1" 2>/dev/null
}

# Get_File_Creation_Time: get file creation time
Get_File_Creation_Time() {
	stat -c '%w' -- "$1" 2>/dev/null
}

# Get_File_Access_Time: get file access time
Get_File_Access_Time() {
	stat -c '%x' -- "$1" 2>/dev/null
}

# Get_File_Modification_Time: get file modification time
Get_File_Modification_Time() {
	stat -c '%y' -- "$1" 2>/dev/null
}

# Get_Date_Part: get date part
Get_Date_Part() {
	local File=$1
	local Format=$2
	local Fallback=$3
	local Time
	Time=$(Get_File_Birth "$File")
	if [[ "$Time" != "0" ]]; then
		date -d "@$Time" "$Format" 2>/dev/null
	else
		printf '%s' "$Fallback"
	fi
}

# ==============================================================================
# 6. MEDIA METADATA EXTRACTORS
# ==============================================================================
Get_Image_WxH() {
	local Resolution
	Resolution=$(identify -ping -format '%wx%h\n' -- "$1" 2>/dev/null | head -n 1 | tr -d '\r\n ')
	printf '%s' "${Resolution:-0x0}"
}

# Get_Media_WxH: get media wx h
Get_Media_WxH() {
	local Resolution
	Resolution=$(timeout 10s ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null)
	Resolution=${Resolution%x}
	printf '%s' "${Resolution:-0x0}"
}

# Get_WxH_Format: get wx h format
Get_WxH_Format() {
	local Input=$1
	local Width Height MaxDimension
	local Level="TINY"
	local Aspect="SQUARE"

	[[ ! "$Input" =~ ^[0-9]+x[0-9]+$ ]] && {
		printf 'ERROR'
		return 1
	}
	[[ "$Input" == "0x0" ]] && {
		printf 'ZERO'
		return 0
	}

	Width=${Input%%x*}
	Height=${Input##*x}
	MaxDimension=$Width
	((Height > Width)) && MaxDimension=$Height

	((MaxDimension > 32)) && Level="MINI"
	((MaxDimension > 512)) && Level="SMALLER"
	((MaxDimension > 1024)) && Level="SMALL"
	((MaxDimension > 2048)) && Level="MEDIUM"
	((MaxDimension > 4096)) && Level="BIG"
	((MaxDimension > 8192)) && Level="BIGGER"
	((MaxDimension > 16384)) && Level="HUGE"

	((Width > Height)) && Aspect="WIDE"
	((Width < Height)) && Aspect="HIGH"

	printf '%s/%s' "$Level" "$Aspect"
}

# Get_Doc_Title: get doc title
Get_Doc_Title() {
	local Title
	Title=$(grep -a '/Title' "$1" 2>/dev/null | head -n 1 | sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_')
	[[ -z "$Title" ]] && Title=$(Get_File_Name "$1")
	printf '%s' "${Title:-ERROR}"
}

# Get_Image_Meta: get image meta
Get_Image_Meta() {
	local Date
	Date=$(timeout 5s ffprobe -v error -show_entries format_tags=date_time_original -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null)
	[[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$1")
	printf '%s' "${Date:-ERROR}"
}

# Get_Audio_Info: get audio info
Get_Audio_Info() {
	local File=$1
	local Artist Album Title Info=""
	Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	Album=$(timeout 10s ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	Title=$(timeout 5s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Album" ]] && Info="${Info:+$Info - }$Album"
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"
	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# Get_Video_Title: get video title
Get_Video_Title() {
	local File=$1
	local Title Artist Info=""
	Title=$(timeout 10s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"
	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# ==============================================================================
# 7. DYNAMIC KEYWORD RESOLVER
# ==============================================================================
Resolve_Path_Segment() {
	local Req=${1,,}
	local File=$2

	case "$Req" in
	year) Get_Date_Part "$File" '+%Y' '0000' ;;
	month) Get_Date_Part "$File" '+%m' '00' ;;
	day) Get_Date_Part "$File" '+%d' '00' ;;
	year+month) Get_Date_Part "$File" '+%Y/%m' '0000/00' ;;
	year+month+day) Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00' ;;
	created) Get_File_Creation_Time "$File" ;;
	modified) Get_File_Modification_Time "$File" ;;
	accessed) Get_File_Access_Time "$File" ;;
	extension) Get_File_Ext "$File" ;;
	mime) printf '%s' "${MIME^^}" ;;
	mime-main) printf '%s' "${MIMEMain^^}" ;;
	mime-sub) printf '%s' "${MIMESub^^}" ;;
	size | format | size+format | format+size)
		if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
			local Dimensions MediaFormat
			[[ "$MIMEMain" == "image" ]] && Dimensions=$(Get_Image_WxH "$File") || Dimensions=$(Get_Media_WxH "$File")
			MediaFormat=$(Get_WxH_Format "$Dimensions")
			if [[ "$MediaFormat" == "ZERO" ]]; then
				printf 'ZERO'
			elif [[ "$Req" == "size" ]]; then
				printf '%s' "$Dimensions"
			elif [[ "$Req" == "format" ]]; then
				printf '%s' "$MediaFormat"
			else
				printf '%s/%s' "$MediaFormat" "$Dimensions"
			fi
		else
			local Bytes Value UnitIndex Divisor
			local -a Units
			Bytes=$(Get_File_Size "$File")
			Value=$Bytes
			UnitIndex=0
			Divisor=1000
			Units=("B" "KB" "MB" "GB" "TB" "PB")

			if [[ "$Req" == "size+format" ]]; then
				Divisor=1024
				Units=("B" "KiB" "MiB" "GiB" "TiB")
			elif [[ "$Req" == format* ]]; then
				Divisor=1000
				Units=("Byte" "Kilo" "Mega" "Giga" "Tera")
			fi

			while ((Value >= Divisor && UnitIndex < ${#Units[@]} - 1)); do
				((UnitIndex += 1))
				Value=$((Value / Divisor))
			done

			case "$Req" in
			size) printf '%s%s' "$Value" "${Units[$UnitIndex]}" ;;
			size+format) printf '%s_%s' "$Value" "${Units[$UnitIndex]}" ;;
			format) printf '%s' "${Units[$UnitIndex]}" ;;
			format+size) printf '%s/%s' "${Units[$UnitIndex]}" "$Value" ;;
			esac
		fi
		;;
	md5 | md5sum) Get_MD5Sum "$File" ;;
	sha) Get_SHA_Keys shasum "$File" ;;
	sha1 | sha224 | sha256 | sha384 | sha512) Get_SHA_Keys "${Req}sum" "$File" ;;
	shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum) Get_SHA_Keys "$Req" "$File" ;;
	random*)
		local Count=${Req#random}
		[[ -z "$Count" ]] && printf '%s' "$RANDOM" || {
			while ((Count > 0)); do
				printf '%s' "$RANDOM"
				((Count -= 1))
			done
		}
		;;
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}

# ==============================================================================
# 8. UI HELPERS
# ==============================================================================
Draw_Line() {
	local Width Symbol
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	Symbol=${1:-=}
	local LineStr
	printf -v LineStr '\n%*s\n\n' "$Width" ''
	Log_Print '%s' "${LineStr// /$Symbol}"
}

# ==============================================================================
# 9. CLI ARGUMENT PARSING & VALIDATION
# ==============================================================================
declare -a InputItems=()

# Parse_Arguments: parse arguments
Parse_Arguments() {
	local Argument
	for Argument in "$@"; do
		case "${Argument,,}" in
		--copy) Mode="copy" ;;
		--move) Mode="move" ;;
		--delete) Mode="delete" ;;
		--remove) Mode="remove" ;;
		--trash) Mode="trash" ;;
		--shred) Mode="shred" ;;
		--mode=*)
			Mode=${Argument#*=}
			Mode=${Mode,,}
			;;
		--type=*) Type=${Argument#*=} ;;
		--recursive) Recursive="yes" ;;
		--pause=*) Pause=${Argument#*=} ;;
		--dirs=*) Dirs=${Argument#*=} ;;
		--subdirs=*) SubDirs=${Argument#*=} ;;
		--rename=*) Rename=${Argument#*=} ;;
		--extension=*) Extension=${Argument#*=} ;;
		--title) Title="yes" ;;
		--replace) Replace="yes" ;;
		--jobs=*) MAX_JOBS=${Argument#*=} ;;
		--colors)
			# Enable ANSI color codes
			BOLD="$_BOLD"
			BLUE="$_BLUE"
			GREEN="$_GREEN"
			RED="$_RED"
			YELLOW="$_YELLOW"
			RESET="$_RESET"
			;;
		--log)
			ENABLE_LOG="yes"
			local TodaysDate
			TodaysDate=$(date +%Y-%m-%d)
			LOG_FILE="./Sort ~ $TodaysDate.log"
			# Initialize or touch log file
			printf '=== Sort.sh Log Started: %s ===\n' "$(date)" >"$LOG_FILE"
			;;
		--*) ;;
		*) InputItems+=("$Argument") ;;
		esac
	done
}

# Validate_Options: validate options
Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		Log_Print 'ERROR: Unsupported mode: %s\n' "$Mode"
		return 1
		;;
	esac
	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		Log_Print 'ERROR: --pause must be a number.\n'
		return 1
	fi
	if [[ -n "$MAX_JOBS" && ! "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
		Log_Print 'ERROR: --jobs must be positive integer.\n'
		return 1
	fi
}

# ==============================================================================
# 10. FILESYSTEM ACTION EXECUTOR
# ==============================================================================
Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	if [[ -z "$Mode" ]]; then
		Log_Print '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		mkdir -p -- "${TargetPath%/*}" || {
			Log_Print 'ERROR: Could not create dir.\n'
			return 1
		}
	fi

	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)
		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				Log_Print 'ERROR: Source and target are same file; refusing: %s\n' "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	case "$Mode" in
	copy)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			Log_Print 'ERROR: Exists: %s\n' "$TargetPath"
			return 1
		}
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			Log_Print 'ERROR: Exists: %s\n' "$TargetPath"
			return 1
		}
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		[[ -e "$TargetPath" ]] && rm -v -f -- "$TargetPath" || Log_Print 'File not found: %s\n' "$TargetPath"
		;;
	trash)
		[[ -e "$TargetPath" ]] && trash-put -- "$TargetPath" || Log_Print 'File not found: %s\n' "$TargetPath"
		;;
	shred)
		[[ -e "$TargetPath" ]] && shred -u -n 1 -- "$TargetPath" || Log_Print 'File not found: %s\n' "$TargetPath"
		;;
	esac
}

# ==============================================================================
# 11. MAIN RECURSIVE FILE PROCESSOR
# ==============================================================================
Sort() {
	local Item
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		((Counter[$Current] += 1))
		local ProgStr="PROGRESS"
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			ProgStr+=" ~ [$Level]=${Counter[$Level]}/${Total[$Level]}"
		done
		# Quick syntax correction for loop string
		# (rebuilding clean prog output)
		ProgStr="PROGRESS"
		for ((Level = 1; Level <= Current; Level++)); do
			ProgStr+=" ~ [$Level]=${Counter[$Level]}/${Total[$Level]}"
		done
		Log_Print '%s\n' "$ProgStr"

		[[ ! -e "$Item" && ! -L "$Item" ]] && {
			Log_Print 'SKIP: Does not exist: %s\n' "$Item"
			continue
		}
		[[ -L "$Item" ]] && {
			Log_Print 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		}

		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				Log_Print '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'
				Children=("$Item"/*)
				((${#Children[@]} > 0)) && Sort "${Children[@]}"
				Draw_Line '<'
				[[ "$Mode" == "move" ]] && rmdir -v -- "$Item" 2>&1
			else
				Log_Print '%bDIR:%b Skipping (use --recursive): %s\n' "$YELLOW" "$RESET" "$Item"
			fi
			Draw_Line '='
			continue
		fi

		[[ ! -f "$Item" ]] && {
			Log_Print 'SKIP: Not regular file: %s\n' "$Item"
			continue
		}

		(
			Draw_Line '-'
			Log_Print '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

			MIME=$(Get_MIME "$Item")
			MIMEMain=${MIME%%/*}
			MIMESub=${MIME#*/}

			Log_Print '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

			if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
				Log_Print '%bSKIP:%b MIME does not match type=%s\n' "$YELLOW" "$RESET" "$Type"
				Draw_Line '-'
				exit 0
			fi

			if [[ -n "$Dirs" ]]; then
				DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
			else
				DestinationDir=${Item%/*}
				[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
			fi

			SubDirectory=""
			[[ -n "$SubDirs" ]] && SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")

			[[ -z "$DestinationDir" ]] && DestinationDir="."
			[[ -n "$SubDirectory" ]] && DestinationDir="${DestinationDir%/}/$SubDirectory"

			Log_Print '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

			FileName=$(Get_File_Name "$Item")
			if [[ -n "$Rename" ]]; then
				TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] && FileName=$TemporaryName
			fi

			if [[ "$Title" == "yes" ]]; then
				TemporaryName=""
				case "${MIMEMain,,}" in
				application) TemporaryName=$(Get_Doc_Title "$Item") ;;
				image) TemporaryName=$(Get_Image_Meta "$Item") ;;
				audio) TemporaryName=$(Get_Audio_Info "$Item") ;;
				video) TemporaryName=$(Get_Video_Title "$Item") ;;
				esac
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] && FileName=$TemporaryName
			fi

			if [[ -n "$Extension" ]]; then
				FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
			else
				FileExtension=$(Get_File_Ext "$Item")
			fi

			FileExtension=${FileExtension,,}
			FileExtension=${FileExtension//\//.}

			if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
				NewName="$FileName.$FileExtension"
			else
				NewName=$FileName
			fi

			TargetPath="${DestinationDir%/}/$NewName"
			[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

			if [[ "$Mode" == "copy" || "$Mode" == "move" ]] && [[ "$Replace" != "yes" ]]; then
				local CollisionIndex=0
				local TargetBase=$FileName
				local TargetExtension=""
				[[ "$NewName" == *.* ]] && TargetExtension=".${NewName##*.}"

				while [[ -e "$TargetPath" ]]; do
					((CollisionIndex += 1))
					NewName="${TargetBase}-(${CollisionIndex})${TargetExtension}"
					TargetPath="${DestinationDir%/}/$NewName"
					[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"
				done
			fi

			Log_Print '%bNEW NAME:%b %s\n' "$YELLOW" "$RESET" "$NewName"
			Log_Print '%bTARGET:%b %s\n' "$YELLOW" "$RESET" "$TargetPath"

			Perform_Action "$Item" "$TargetPath"
			[[ -n "$Pause" ]] && sleep "$Pause"
			Draw_Line '-'
		) &

		if ((MAX_JOBS > 1)); then
			while (($(jobs -r | wc -l) >= MAX_JOBS)); do
				sleep 0.1
			done
		fi
	done

	((Current -= 1))
}

# ==============================================================================
# 12. HELP TEXT & SCRIPT ENTRY
# ==============================================================================
Show_Help() {
	Draw_Line '━'
	cat <<'EOF'
Sort.sh v2.3 - Organizer with --colors and --log support
USAGE:
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY ...

NEW OPTIONS:
  --colors          Enables colored screen output.
  --log             Creates a log file: 'Sort ~ YYYY-MM-DD.log' in working directory.
  --jobs=N          Concurrent threads (default: 4).
EOF
	Draw_Line '━'
}

if (($# == 0)); then
	Show_Help
	exit 0
fi

Parse_Arguments "$@"
Validate_Options || exit 2

if ((${#InputItems[@]} == 0)); then
	Log_Print 'ERROR: No input paths specified.\n'
	exit 2
fi

Sort "${InputItems[@]}"
wait

Log_Print '\n%b--- DONE ---%b\n\n' "$GREEN" "$RESET"
echo "Thanks for using HEjder scripts!"
exit 0