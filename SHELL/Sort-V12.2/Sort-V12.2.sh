#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V12.2.sh                                                     #
# Version : 12.2                                                              #
# Desc    : Threaded file organizer with logging                              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# ==============================================================================
# Sort.sh v5.1 (Threadded, Loggging, Displayed) - Media-Intelligent File Organizer
# Developed by: HEjder
#
# PURPOSE:
#   Organizes, renames, and sorts files based on MIME types, filesystem
#   timestamps, cryptographic hashes, and embedded media metadata.
#
# FEATURES:
#   - Multi-threaded worker pool (--jobs=N) with dedicated slot tracking
#   - Static TUI dashboard header with per-thread live status lines
#   - Theme-adaptive high-contrast ANSI colors (--colors)
#   - Thread-safe plain-text logging (--log -> 'Sort ~ YYYY-MM-DD.log')
#   - Safe dry-run mode by default when no operational mode is specified
# ==============================================================================

# ==============================================================================
# 1. TERMINAL COLORS & UI CONFIGURATION
# ==============================================================================
# High-intensity + Bold ANSI sequences provide strong contrast on both dark
# and light terminal backgrounds. They remain empty unless --colors is set.

_BOLD='\e[1m'
_BLUE='\e[1;94m'
_CYAN='\e[1;96m'
_GREEN='\e[1;92m'
_RED='\e[1;91m'
_YELLOW='\e[1;93m'
_DIM='\e[2m'
_RESET='\e[0m'

BOLD=""
BLUE=""
CYAN=""
GREEN=""
RED=""
YELLOW=""
DIM=""
RESET=""

# Logging and TUI state
ENABLE_COLORS="no"
ENABLE_LOG="no"
LOG_FILE=""
TUI_ACTIVE="no"
HEADER_ROWS=8

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
	[flock]="util-linux"
	[grep]="grep"
	[sed]="sed"
	[ffprobe]="ffmpeg"
	[identify]="imagemagick"
	[tput]="ncurses-bin / ncurses"
)

Errors=0
for Key in "${!Required[@]}"; do
	if ! command -v "$Key" >/dev/null 2>&1; then
		printf 'ERROR: Command "%s" is missing. Install package: %s\n' \
			"$Key" "${Required[$Key]}"
		((Errors += 1))
	fi
done

if ((Errors > 0)); then
	printf '\nERROR: %d required command(s) missing; cannot continue.\n' "$Errors"
	exit 1
fi

# ==============================================================================
# 3. GLOBAL DEFAULTS, SLOT POOL & SIGNAL TRAPS
# ==============================================================================
OIFS=$IFS

# Operational & filtering options
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

# Progress tracking across recursion depths
declare -a Total Counter
Current=0
FilesProcessed=0

# Directory for tracking active thread slot locks (1..MAX_JOBS)
SLOT_DIR=""

# ------------------------------------------------------------------------------
# Exit()
# Waits for active worker threads, restores cursor visibility, and cleans up.
# ------------------------------------------------------------------------------
Exit() {
	local Status=${1:-0}
	trap - EXIT

	wait

	# Restore cursor visibility if TUI was active
	if [[ "$TUI_ACTIVE" == "yes" ]]; then
		local BottomRow=$((HEADER_ROWS + MAX_JOBS + 3))
		printf '\033[%d;1H\033[?25h\n' "$BottomRow"
	fi

	# Remove temporary thread slot tracking directory
	[[ -n "$SLOT_DIR" && -d "$SLOT_DIR" ]] && rm -rf -- "$SLOT_DIR"

	IFS=$OIFS
	exit "$Status"
}

# ------------------------------------------------------------------------------
# Break()
# Handles Ctrl+C (SIGINT) cleanly.
# ------------------------------------------------------------------------------
Break() {
	Write_Log "ABORT: Terminated by user (SIGINT)."
	Exit 130
}

trap 'Exit $?' EXIT
trap Break INT

shopt -s dotglob nullglob

# ==============================================================================
# 4. LOGGING & TUI RENDERING ENGINE
# ==============================================================================

# ------------------------------------------------------------------------------
# Write_Log()
# Appends a clean, ANSI-stripped timestamped message to the log file using flock
# so concurrent threads never interleave log lines.
# ------------------------------------------------------------------------------
Write_Log() {
	[[ "$ENABLE_LOG" != "yes" || -z "$LOG_FILE" ]] && return 0

	local RawMsg=$1
	local CleanMsg Timestamp
	CleanMsg=$(printf '%b' "$RawMsg" | sed -r 's/\x1B\[[0-9;]*[mK]//g')
	Timestamp=$(date '+%H:%M:%S')

	(
		flock -x 200
		printf '[%s] %s\n' "$Timestamp" "$CleanMsg" >&200
	) 200>>"$LOG_FILE"
}

# ------------------------------------------------------------------------------
# Init_TUI()
# Clears the screen, hides the cursor, draws the static header section, and
# pre-allocates isolated status lines for each worker thread slot.
# ------------------------------------------------------------------------------
Init_TUI() {
	TUI_ACTIVE="yes"
	local Width
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}

	local Rule
	printf -v Rule '%*s' "$Width" ''
	Rule=${Rule// /=}

	# Clear screen, move cursor to (1,1), hide cursor (\033[?25l)
	printf '\033[2J\033[1;1H\033[?25l'

	# --- Static Header Section (Rows 1 to 8) ---
	printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
	printf '%b  Sort.sh v2.4%b | Media-Intelligent File Organizer\n' "$BOLD" "$RESET"
	printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
	printf '  %bMode:%b %-10s | %bThreads:%b %-4s | %bRecursive:%b %-5s | %bLog:%b %s\n' \
		"$YELLOW" "$RESET" "${Mode:-DRY-RUN}" \
		"$YELLOW" "$RESET" "$MAX_JOBS" \
		"$YELLOW" "$RESET" "$Recursive" \
		"$YELLOW" "$RESET" "${LOG_FILE:-OFF}"
	printf '  %bDirs:%b %-10s | %bSubDirs:%b %-10s | %bRename:%b %s\n' \
		"$CYAN" "$RESET" "${Dirs:-<source>}" \
		"$CYAN" "$RESET" "${SubDirs:-<none>}" \
		"$CYAN" "$RESET" "${Rename:-<original>}"
	printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
	printf '  %bACTIVE WORKER THREADS:%b\n' "$BOLD" "$RESET"
	printf '%b%s%b\n' "$DIM" "${Rule//=/-}" "$RESET"

	# --- Pre-draw empty thread slots (Rows 9 to 9+MAX_JOBS-1) ---
	local Slot
	for ((Slot = 1; Slot <= MAX_JOBS; Slot++)); do
		local Row=$((HEADER_ROWS + Slot))
		printf '\033[%d;1H\033[K  %b[Thread %02d]%b %bIDLE%b\n' \
			"$Row" "$CYAN" "$Slot" "$RESET" "$DIM" "$RESET"
	done

	# Footer separator below thread pool
	local FooterRow=$((HEADER_ROWS + MAX_JOBS + 1))
	printf '\033[%d;1H\033[K%b%s%b\n' "$FooterRow" "$BLUE" "$Rule" "$RESET"
}

# ------------------------------------------------------------------------------
# Update_Thread_Slot()
# Updates a single thread's dedicated line in place without scrolling.
# Args: $1 = SlotID (1..MAX_JOBS) | $2 = Status badge | $3 = Badge color | $4 = Detail text
# ------------------------------------------------------------------------------
Update_Thread_Slot() {
	local SlotID=$1
	local Badge=$2
	local BadgeColor=$3
	local Detail=$4

	local TargetRow=$((HEADER_ROWS + SlotID))
	local Width MaxDetail
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}

	# Truncate detail string so it never wraps onto the next thread's row
	MaxDetail=$((Width - 28))
	((MaxDetail < 20)) && MaxDetail=20
	if ((${#Detail} > MaxDetail)); then
		Detail="...${Detail: -$((MaxDetail - 3))}"
	fi

	# Lock stdout briefly so cursor positioning + line clear are atomic
	(
		flock -x 201
		printf '\033[%d;1H\033[K  %b[Thread %02d]%b %b%-10s%b %s' \
			"$TargetRow" "$CYAN" "$SlotID" "$RESET" "$BadgeColor" "$Badge" "$RESET" "$Detail"
	) 201>"$SLOT_DIR/tty.lock"
}

# ------------------------------------------------------------------------------
# Update_Header_Dir()
# Updates the footer status bar below the thread pool with the current directory.
# ------------------------------------------------------------------------------
Update_Header_Dir() {
	local CurrentDir=$1
	local StatusRow=$((HEADER_ROWS + MAX_JOBS + 2))
	local Width MaxLen
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	MaxLen=$((Width - 18))
	((MaxLen < 20)) && MaxLen=20

	if ((${#CurrentDir} > MaxLen)); then
		CurrentDir="...${CurrentDir: -$((MaxLen - 3))}"
	fi

	(
		flock -x 201
		printf '\033[%d;1H\033[K  %bScanning:%b %s' \
			"$StatusRow" "$BLUE" "$RESET" "$CurrentDir"
	) 201>"$SLOT_DIR/tty.lock"
}

# ------------------------------------------------------------------------------
# Acquire_Slot() / Release_Slot()
# Allocates an unused slot number (1..MAX_JOBS) for a worker thread.
# ------------------------------------------------------------------------------
Acquire_Slot() {
	local Slot
	while true; do
		for ((Slot = 1; Slot <= MAX_JOBS; Slot++)); do
			# mkdir is atomic on POSIX filesystems—acts as a lock-free slot claim
			if mkdir "$SLOT_DIR/slot_$Slot" 2>/dev/null; then
				printf '%d' "$Slot"
				return 0
			fi
		done
		sleep 0.05
	done
}

# Release_Slot: release slot
Release_Slot() {
	local Slot=$1
	rmdir "$SLOT_DIR/slot_$Slot" 2>/dev/null
}

# ==============================================================================
# 5. FILE ATTRIBUTE & CHECKSUM HELPERS
# ==============================================================================
Get_MD5Sum() {
	local File=$1
	local Sum
	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Get_SHA_Keys: get sha keys
Get_SHA_Keys() {
	local CommandName=$1
	local File=$2
	local Sum
	[[ ! -x "/usr/bin/$CommandName" ]] && {
		printf 'ERROR'
		return 1
	}
	Sum=$("/usr/bin/$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Get_SHA256Sum: get sha256 sum
Get_SHA256Sum() {
	local File=$1
	local Sum
	Sum=$(sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Get_MIME: get mime
Get_MIME() {
	local File=$1
	local MIME
	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	printf '%s' "${MIME:-ERROR}"
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
	local Size
	Size=$(stat -c '%s' -- "$1" 2>/dev/null)
	printf '%d' "${Size:-0}"
}

# Get_File_Birth: get file birth
Get_File_Birth() {
	local Time
	Time=$(stat -c '%W' -- "$1" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Creation_Time() { stat -c '%w' -- "$1" 2>/dev/null; }
Get_File_Access_Time() { stat -c '%x' -- "$1" 2>/dev/null; }
Get_File_Modification_Time() { stat -c '%y' -- "$1" 2>/dev/null; }

# Get_Date_Part: get date part
Get_Date_Part() {
	local File=$1 Format=$2 Fallback=$3 Time
	Time=$(Get_File_Birth "$File")
	if [[ "$Time" != "0" ]]; then
		date -d "@$Time" "$Format" 2>/dev/null
	else
		printf '%s' "$Fallback"
	fi
}

# ==============================================================================
# 6. MEDIA & DOCUMENT METADATA EXTRACTORS
# ==============================================================================
Get_Image_WxH() {
	local Resolution
	Resolution=$(identify -ping -format '%wx%h\n' -- "$1" 2>/dev/null | head -n 1 | tr -d '\r\n ')
	printf '%s' "${Resolution:-0x0}"
}

# Get_Media_WxH: get media wx h
Get_Media_WxH() {
	local Resolution
	Resolution=$(
		timeout 10s ffprobe -v error -select_streams v:0 \
			-show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null
	)
	Resolution=${Resolution%x}
	printf '%s' "${Resolution:-0x0}"
}

# Get_WxH_Format: get wx h format
Get_WxH_Format() {
	local Input=$1
	local Width Height MaxDimension
	local Level="TINY" Aspect="SQUARE"

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
	Title=$(
		grep -a '/Title' "$1" 2>/dev/null | head -n 1 |
			sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_'
	)
	[[ -z "$Title" ]] && Title=$(Get_File_Name "$1")
	printf '%s' "${Title:-ERROR}"
}

# Get_Image_Meta: get image meta
Get_Image_Meta() {
	local Date
	Date=$(
		timeout 5s ffprobe -v error -show_entries format_tags=date_time_original \
			-of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
	)
	[[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$1")
	printf '%s' "${Date:-ERROR}"
}

# Get_Audio_Info: get audio info
Get_Audio_Info() {
	local File=$1 Artist Album Title Info=""
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
	local File=$1 Title Artist Info=""
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
		if [[ -z "$Count" ]]; then
			printf '%s' "$RANDOM"
		elif [[ "$Count" =~ ^[0-9]+$ ]]; then
			while ((Count > 0)); do
				printf '%s' "$RANDOM"
				((Count -= 1))
			done
		else
			printf 'ERROR'
			return 1
		fi
		;;
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}

# ==============================================================================
# 8. CLI ARGUMENT PARSING & VALIDATION
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
		--compare) Compare="yes" ;;
		--colors)
			ENABLE_COLORS="yes"
			BOLD="$_BOLD"
			BLUE="$_BLUE"
			CYAN="$_CYAN"
			GREEN="$_GREEN"
			RED="$_RED"
			YELLOW="$_YELLOW"
			DIM="$_DIM"
			RESET="$_RESET"
			;;
		--log)
			ENABLE_LOG="yes"
			local TodaysDate
			TodaysDate=$(date +%Y-%m-%d)
			LOG_FILE="./Sort ~ $TodaysDate.log"
			printf '=== Sort.sh v2.4 Log Started: %s ===\n' "$(date)" >"$LOG_FILE"
			;;
		--*)
			printf 'WARNING: Unknown option: %s (ignored)\n' "$Argument"
			;;
		*)
			InputItems+=("$Argument")
			;;
		esac
	done
}

# Validate_Options: validate options
Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf 'ERROR: Unsupported mode: %s\n' "$Mode"
		return 1
		;;
	esac

	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf 'ERROR: --pause must be a non-negative number.\n'
		return 1
	fi

	if [[ -n "$MAX_JOBS" && ! "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
		printf 'ERROR: --jobs must be a positive integer.\n'
		return 1
	fi

	if [[ "$Mode" == "trash" ]] && ! command -v trash-put >/dev/null 2>&1; then
		printf 'ERROR: --mode=trash requires trash-put (trash-cli).\n'
		return 1
	fi

	if [[ "$Mode" == "shred" ]] && ! command -v shred >/dev/null 2>&1; then
		printf 'ERROR: --mode=shred requires shred (coreutils).\n'
		return 1
	fi
}

# ==============================================================================
# 9. FILESYSTEM ACTION EXECUTOR
# ==============================================================================
Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SlotID=$3
	local SourceReal TargetReal

	# Dry-Run Preview
	if [[ -z "$Mode" ]]; then
		Update_Thread_Slot "$SlotID" "DRY-RUN" "$BLUE" "$SourcePath -> $TargetPath"
		Write_Log "TEST: $SourcePath -> $TargetPath"
		return 0
	fi

	# Create target directories for copy/move
	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Failed creating dir: ${TargetPath%/*}"
			Write_Log "ERROR: Could not create directory for $TargetPath"
			return 1
		fi
	fi

	# Same-file safeguard for destructive operations
	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)
		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				Update_Thread_Slot "$SlotID" "REFUSED" "$RED" "Same file: $SourcePath"
				Write_Log "ERROR: Refusing destructive action on same file: $SourcePath"
				return 1
				;;
			esac
		fi
	fi

	case "$Mode" in
	copy)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			Update_Thread_Slot "$SlotID" "EXISTS" "$YELLOW" "$TargetPath"
			Write_Log "SKIP (EXISTS): $TargetPath"
			return 1
		fi
		if cp -f -- "$SourcePath" "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "COPIED" "$GREEN" "$TargetPath"
			Write_Log "COPY: $SourcePath -> $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Copy failed: $SourcePath"
			Write_Log "ERROR: Copy failed for $SourcePath"
		fi
		;;
	move)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			Update_Thread_Slot "$SlotID" "EXISTS" "$YELLOW" "$TargetPath"
			Write_Log "SKIP (EXISTS): $TargetPath"
			return 1
		fi
		if mv -f -- "$SourcePath" "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "MOVED" "$GREEN" "$TargetPath"
			Write_Log "MOVE: $SourcePath -> $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Move failed: $SourcePath"
			Write_Log "ERROR: Move failed for $SourcePath"
		fi
		;;
	delete | remove)
		if [[ -e "$TargetPath" ]] && rm -f -- "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "DELETED" "$RED" "$TargetPath"
			Write_Log "DELETE: $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "MISSING" "$YELLOW" "$TargetPath"
			Write_Log "WARN: Target not found for delete: $TargetPath"
		fi
		;;
	trash)
		if [[ -e "$TargetPath" ]] && trash-put -- "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "TRASHED" "$RED" "$TargetPath"
			Write_Log "TRASH: $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "MISSING" "$YELLOW" "$TargetPath"
			Write_Log "WARN: Target not found for trash: $TargetPath"
		fi
		;;
	shred)
		if [[ -e "$TargetPath" ]] && shred -u -n 1 -- "$TargetPath" 2>/dev/null; then
			Update_Thread_Slot "$SlotID" "SHREDDED" "$RED" "$TargetPath"
			Write_Log "SHRED: $TargetPath"
		else
			Update_Thread_Slot "$SlotID" "MISSING" "$YELLOW" "$TargetPath"
			Write_Log "WARN: Target not found for shred: $TargetPath"
		fi
		;;
	esac
}

# ==============================================================================
# 10. MAIN RECURSIVE FILE PROCESSOR
# ==============================================================================
Sort() {
	local Item
	local -a Children

	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		((Counter[$Current] += 1))

		[[ ! -e "$Item" && ! -L "$Item" ]] && {
			Write_Log "SKIP: Missing $Item"
			continue
		}
		[[ -L "$Item" ]] && {
			Write_Log "SKIP: Symlink $Item"
			continue
		}

		# --- Directory Handling ---
		if [[ -d "$Item" ]]; then
			Update_Header_Dir "$Item"
			if [[ "$Recursive" == "yes" ]]; then
				Write_Log "DIR: Entering $Item"
				Children=("$Item"/*)
				((${#Children[@]} > 0)) && Sort "${Children[@]}"

				# Wait for files inside this folder before attempting rmdir
				if [[ "$Mode" == "move" ]]; then
					wait
					rmdir -- "$Item" 2>/dev/null && Write_Log "RMDIR: Removed empty $Item"
				fi
			else
				Write_Log "DIR: Skipping (no --recursive): $Item"
			fi
			continue
		fi

		[[ ! -f "$Item" ]] && continue

		# --- Claim a Thread Slot & Dispatch Worker ---
		local AssignedSlot
		AssignedSlot=$(Acquire_Slot)

		(
			# Ensure slot lock is always released when subshell finishes
			trap 'Release_Slot "$AssignedSlot"' EXIT

			Update_Thread_Slot "$AssignedSlot" "ANALYZING" "$YELLOW" "$Item"

			local MIME MIMEMain MIMESub
			MIME=$(Get_MIME "$Item")
			MIMEMain=${MIME%%/*}
			MIMESub=${MIME#*/}

			# Filter check
			if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
				Update_Thread_Slot "$AssignedSlot" "SKIPPED" "$DIM" "MIME mismatch ($MIME): ${Item##*/}"
				Write_Log "SKIP (MIME $MIME): $Item"
				exit 0
			fi

			# Step 1: Destination Directory
			local DestinationDir SubDirectory
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

			# Step 2: Destination Filename
			local FileName TemporaryName FileExtension NewName TargetPath
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

			# Step 3: Collision Avoidance
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

			# Step 4: Execute Action
			Perform_Action "$Item" "$TargetPath" "$AssignedSlot"

			[[ -n "$Pause" ]] && sleep "$Pause"
		) &
	done

	((Current -= 1))
}

# ==============================================================================
# 11. CLI USAGE & DOCUMENTATION
# ==============================================================================
Show_Help() {
	cat <<'EOF'
================================================================================
Sort.sh v2.4 - Media-Intelligent File Organizer
Developed by: HEjder
================================================================================

USAGE:
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

OPERATIONAL MODES:
  --mode=copy       Copy files to calculated destination.
  --mode=move       Move files to calculated destination.
  --mode=delete     Permanently delete target file (alias: --mode=remove).
  --mode=trash      Send target file to system trash (requires trash-cli).
  --mode=shred      Securely overwrite and delete target file.
  (Shorthands: --copy, --move, --delete, --remove, --trash, --shred)

DISPLAY, LOGGING & THREADING:
  --jobs=N          Number of concurrent worker threads (default: 4).
  --colors          Enable high-contrast ANSI colors for dark/light terminals.
  --log             Write a plain-text log to './Sort ~ YYYY-MM-DD.log'.

FILTERING & PROCESSING:
  --type=VALUE      Process only files whose MIME type contains VALUE.
  --recursive       Process subdirectories recursively.
  --pause=SECONDS   Wait X seconds after each file action.

DESTINATION & NAMING:
  --dirs=VALUE      Primary directory component (e.g. mime-main, year).
  --subdirs=VALUE   Secondary directory component (e.g. format+size, month).
  --rename=VALUE    Override filename (e.g. sha256sum, md5sum, year).
  --extension=VALUE Override file extension (e.g. extension, mime-sub).
  --title           Extract embedded metadata for titles (Audio/Video/Image/PDF).
  --replace         Overwrite existing destination files instead of numbering.

DYNAMIC VALUES:
  Dates:      year, month, day, year+month, year+month+day, created, modified, accessed
  Identity:   extension, mime, mime-main, mime-sub, md5sum, sha256sum, sha512sum, randomN
  Media/Size: size, format, size+format, format+size
================================================================================
EOF
}

# ==============================================================================
# 12. SCRIPT ENTRY POINT
# ==============================================================================
if (($# == 0)); then
	Show_Help
	exit 0
fi

Parse_Arguments "$@"
Validate_Options || exit 2

if ((${#InputItems[@]} == 0)); then
	printf 'ERROR: No input files or directories were supplied.\n'
	exit 2
fi

# Create temporary directory for atomic slot locks
SLOT_DIR=$(mktemp -d /tmp/sort_sh_slots.XXXXXX)

# Render static header & allocate worker thread display rows
Init_TUI
Update_Header_Dir "Starting..."

# Execute sorting pipeline
Sort "${InputItems[@]}"

# Wait for all remaining background threads to finish
wait

# Mark all thread slots as DONE on screen
for ((s = 1; s <= MAX_JOBS; s++)); do
	Update_Thread_Slot "$s" "DONE" "$GREEN" "Completed"
done
Update_Header_Dir "All tasks finished!"
Write_Log "=== Sort.sh v2.4 Finished: $(date) ==="

echo "Thanks for using HEjder scripts!"
exit 0