#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V13.0.sh                                                     #
# Version : 13.0                                                              #
# Desc    : Commented edition of the media-intelligent organizer              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# ==============================================================================
# Sort.sh v3.0 - Media-Intelligent File Organizer
# Developed by: HEjder
#
# PURPOSE:
#   Automatically sorts, renames, and organizes files based on their MIME types,
#   filesystem timestamps, cryptographic hashes, and embedded media metadata.
#   Destination paths and filenames are dynamically constructed using keywords.
#
# SAFETY GUARANTEE:
#   By default (when no operational mode is passed), this script executes in
#   DRY-RUN mode. It previews every target path without modifying, moving, or
#   deleting any files on disk.
# ==============================================================================

# ==============================================================================
# 1. TERMINAL COLORS & STYLING
# ==============================================================================
# ANSI escape codes used to format terminal output. These variables are passed
# into printf using the '%b' specifier so Bash expands the escape sequences.

BOLD='\e[1m'
BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'

# High-intensity bold variants retained for backward compatibility.
BOLDBLUE='\e[1;34m'
BOLDGREEN='\e[1;32m'
BOLDRED='\e[1;31m'
BOLDYELLOW='\e[1;33m'

# Resets terminal attributes back to default colors/weight.
RESET='\e[0m'

# ==============================================================================
# 2. SYSTEM DEPENDENCY CHECK
# ==============================================================================
# Before touching any files, verify that all mandatory external binaries exist
# in the user's PATH. Built-in shell keywords (printf, read, [[, etc.) are
# excluded since they are native to Bash.

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

# Note on optional dependencies:
#   Tools like 'trash-put' (--mode=trash), 'shred' (--mode=shred), and extra
#   hashing utilities (sha1deep, sha512sum, etc.) are validated on demand only
#   when the user explicitly requests those features.

Errors=0

for Key in "${!Required[@]}"; do
	if ! command -v "$Key" >/dev/null 2>&1; then
		printf '%bERROR:%b Command "%s" is missing. Install package: %s\n' \
			"$RED" "$RESET" "$Key" "${Required[$Key]}"
		((Errors += 1))
	else
		printf '%bOK:%b Command "%s" is available.\n' \
			"$GREEN" "$RESET" "$Key"
	fi
done

# Abort execution immediately if any mandatory tool is missing.
if ((Errors > 0)); then
	printf '\n%bERROR:%b %d required command(s) missing; cannot continue.\n' \
		"$RED" "$RESET" "$Errors"
	exit 1
fi

# ==============================================================================
# 3. GLOBAL CONFIGURATION & SIGNAL TRAPS
# ==============================================================================

# Save the caller's Internal Field Separator (IFS) so we can safely restore
# the shell environment upon exit.
OIFS=$IFS

# Default state: empty Mode triggers a safe Dry Run.
Mode=""

# User-configurable CLI options (populated during argument parsing).
Type=""
Recursive="no"
Dirs=""
SubDirs=""
Rename=""
Title=""
Extension=""
Replace="no"
Pause=""

# Legacy compatibility flags (accepted by parser, currently unimplemented).
MAX_JOBS=4
Compare="no"

# Arrays to track progress counters independently across recursion levels.
# Index 1 = top-level arguments, Index 2 = first subdirectory depth, etc.
declare -a Total Counter
Current=0

# ------------------------------------------------------------------------------
# Exit()
# Centralized cleanup handler triggered on normal completion or interruption.
# ------------------------------------------------------------------------------
Exit() {
	local Status=${1:-0}

	# Unset the EXIT trap immediately to prevent infinite recursion when 'exit' runs.
	trap - EXIT

	printf 'Waiting for background jobs to finish...\n'
	wait

	# Restore original shell word-splitting behavior.
	IFS=$OIFS

	printf 'Finished.\n'
	exit "$Status"
}

# ------------------------------------------------------------------------------
# Break()
# Converts Ctrl+C (SIGINT) into a clean shutdown via Exit() with code 130.
# ------------------------------------------------------------------------------
Break() {
	printf '\nTerminated by user!\n'
	Exit 130
}

# Register traps for normal termination and user interrupts.
trap 'Exit $?' EXIT
trap Break INT

# Shell globbing options:
#   dotglob  -> '*' matches hidden dotfiles (e.g., .gitignore)
#   nullglob -> unmatched globs expand to nothing instead of a literal '*' string
shopt -s dotglob nullglob

# ==============================================================================
# 4. FILE ATTRIBUTE & CHECKSUM HELPERS
# ==============================================================================

# Compute the MD5 hexadecimal digest of a file.
Get_MD5Sum() {
	local File=$1
	local Sum

	# '--' ensures filenames starting with a hyphen aren't parsed as flags.
	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Execute an optional hashing binary located in /usr/bin (e.g., sha512sum).
Get_SHA_Keys() {
	local CommandName=$1
	local File=$2
	local Sum

	if [[ ! -x "/usr/bin/$CommandName" ]]; then
		printf 'ERROR'
		return 1
	fi

	Sum=$("/usr/bin/$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Compute the SHA-256 hexadecimal digest of a file.
Get_SHA256Sum() {
	local File=$1
	local Sum

	Sum=$(sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Query libmagic via 'file' to determine the exact MIME type (e.g., image/png).
Get_MIME() {
	local File=$1
	local MIME

	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	printf '%s' "${MIME:-ERROR}"
}

# Strip directory path and final file extension.
# Example: "/path/to/archive.tar.gz" -> "archive.tar"
Get_File_Name() {
	local Name=${1##*/}
	printf '%s' "${Name%.*}"
}

# Extract only the final file extension (without the leading dot).
Get_File_Ext() {
	local BaseName=${1##*/}

	# Edge-case guard: files with no dot ("Makefile") or single-dot hidden
	# dotfiles (".bashrc") have no extension and return an empty string.
	if [[ "$BaseName" != *.* || ("$BaseName" == .* && "$BaseName" != *.*.*) ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}

# Retrieve exact byte size using GNU stat.
Get_File_Size() {
	local File=$1
	local Size

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}

# Retrieve filesystem birth (creation) time as a Unix epoch timestamp.
# Returns "0" on filesystems that do not track file creation times.
Get_File_Birth() {
	local File=$1
	local Time

	Time=$(stat -c '%W' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Retrieve formatted filesystem timestamps (Creation, Access, Modification).
Get_File_Creation_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%w' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Get_File_Access_Time: get file access time
Get_File_Access_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%x' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Get_File_Modification_Time: get file modification time
Get_File_Modification_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Format a file's birth timestamp using 'date'.
# Args: $1 = File path | $2 = date format string | $3 = fallback if birth is 0
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
# 5. MEDIA & DOCUMENT METADATA EXTRACTORS
# ==============================================================================

# Extract image dimensions (WIDTHxHEIGHT) via ImageMagick.
# For multi-frame files (like GIFs), 'head -n 1' isolates the first frame.
Get_Image_WxH() {
	local File=$1
	local Resolution

	Resolution=$(
		identify -ping -format '%wx%h\n' -- "$File" 2>/dev/null |
			head -n 1 |
			tr -d '\n\r '
	)

	printf '%s' "${Resolution:-0x0}"
}

# Extract primary video stream dimensions (WIDTHxHEIGHT) via ffprobe.
# Wrapped in 'timeout 10s' to prevent corrupt video streams from hanging.
Get_Media_WxH() {
	local File=$1
	local Resolution

	Resolution=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams v:0 \
			-show_entries stream=width,height \
			-of csv=s=x:p=0 \
			"$File" 2>/dev/null
	)

	# Strip trailing 'x' in case ffprobe reports width without height.
	Resolution=${Resolution%x}

	printf '%s' "${Resolution:-0x0}"
}

# Categorize a WIDTHxHEIGHT string into a human-readable size tier and
# aspect ratio label (e.g., "1920x1080" -> "SMALL/WIDE").
Get_WxH_Format() {
	local Input=$1
	local Width Height MaxDimension
	local Level="TINY"
	local Aspect="SQUARE"

	# Step 1: Validate format strictly as DIGITSxDIGITS.
	if [[ ! "$Input" =~ ^[0-9]+x[0-9]+$ ]]; then
		printf 'ERROR'
		return 1
	fi

	# Step 2: Handle unreadable or zero-dimension media cleanly.
	if [[ "$Input" == "0x0" ]]; then
		printf 'ZERO'
		return 0
	fi

	# Step 3: Split dimensions and find the longest edge.
	Width=${Input%%x*}
	Height=${Input##*x}
	MaxDimension=$Width
	((Height > Width)) && MaxDimension=$Height

	# Step 4: Assign resolution tier based on longest edge pixel count.
	((MaxDimension > 32)) && Level="MINI"
	((MaxDimension > 512)) && Level="SMALLER"
	((MaxDimension > 1024)) && Level="SMALL"
	((MaxDimension > 2048)) && Level="MEDIUM"
	((MaxDimension > 4096)) && Level="BIG"
	((MaxDimension > 8192)) && Level="BIGGER"
	((MaxDimension > 16384)) && Level="HUGE"

	# Step 5: Determine orientation.
	((Width > Height)) && Aspect="WIDE"
	((Width < Height)) && Aspect="HIGH"

	printf '%s/%s' "$Level" "$Aspect"
}

# Perform a lightweight regex scan on a PDF file for its internal /Title tag.
# Falls back to the existing filename if no title tag is found.
Get_Doc_Title() {
	local File=$1
	local Title

	Title=$(
		grep -a '/Title' "$File" 2>/dev/null |
			head -n 1 |
			sed 's/.*(\(.*\)).*/\1/' |
			tr -d '/\\:*?"<>|' |
			tr ' ' '_'
	)

	[[ -z "$Title" ]] && Title=$(Get_File_Name "$File")

	printf '%s' "${Title:-ERROR}"
}

# Extract EXIF/container creation date from an image; falls back to stat time.
Get_Image_Meta() {
	local File=$1
	local Date

	Date=$(
		timeout 5s ffprobe \
			-v error \
			-show_entries format_tags=date_time_original \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	[[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$File")

	printf '%s' "${Date:-ERROR}"
}

# Build a sanitized "Artist - Album - Title" string from audio metadata tags.
Get_Audio_Info() {
	local File=$1
	local Artist Album Title Info=""

	Artist=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries format_tags=artist \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	Album=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries format_tags=album \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	Title=$(
		timeout 5s ffprobe \
			-v error \
			-show_entries format_tags=title \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	# Concatenate only non-empty tags separated by " - ".
	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Album" ]] && Info="${Info:+$Info - }$Album"
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"

	# Strip characters that are illegal or hazardous in filenames.
	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# Build a sanitized "Artist - Title" string from video container metadata.
Get_Video_Title() {
	local File=$1
	local Title Artist Info=""

	Title=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries format_tags=title \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	Artist=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries format_tags=artist \
			-of default=noprint_wrappers=1:nokey=1 \
			"$File" 2>/dev/null
	)

	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"

	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# ==============================================================================
# 6. DYNAMIC KEYWORD RESOLVER
# ==============================================================================
# Translates user-supplied keywords (e.g., "year+month", "sha256sum", "format")
# into concrete path or filename strings for a given file.
#
# Relies on MIME, MIMEMain, and MIMESub already being populated in Sort().

# Resolve_Path_Segment: resolve path segment
Resolve_Path_Segment() {
	local Req=${1,,} # Normalize keyword to lowercase
	local File=$2

	case "$Req" in
	# --- Date & Time Keywords ---
	year) Get_Date_Part "$File" '+%Y' '0000' ;;
	month) Get_Date_Part "$File" '+%m' '00' ;;
	day) Get_Date_Part "$File" '+%d' '00' ;;
	year+month) Get_Date_Part "$File" '+%Y/%m' '0000/00' ;;
	year+month+day) Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00' ;;
	created) Get_File_Creation_Time "$File" ;;
	modified) Get_File_Modification_Time "$File" ;;
	accessed) Get_File_Access_Time "$File" ;;

	# --- File Type & MIME Keywords ---
	extension) Get_File_Ext "$File" ;;
	mime) printf '%s' "${MIME^^}" ;;
	mime-main) printf '%s' "${MIMEMain^^}" ;;
	mime-sub) printf '%s' "${MIMESub^^}" ;;

	# --- Context-Aware Size & Format Keywords ---
	size | format | size+format | format+size)
		if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
			# Branch A: Visual media -> resolve pixel dimensions & tier
			local Dimensions MediaFormat

			if [[ "$MIMEMain" == "image" ]]; then
				Dimensions=$(Get_Image_WxH "$File")
			else
				Dimensions=$(Get_Media_WxH "$File")
			fi

			MediaFormat=$(Get_WxH_Format "$Dimensions")

			# Prevent "ZERO/0x0" paths when dimensions cannot be read
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
			# Branch B: General files -> scale byte size into readable units
			local Bytes Value UnitIndex Divisor
			local -a Units

			Bytes=$(Get_File_Size "$File")
			Value=$Bytes
			UnitIndex=0
			Divisor=1000
			Units=("B" "KB" "MB" "GB" "TB" "PB")

			# Switch to binary (1024) or full-word labels depending on keyword
			if [[ "$Req" == "size+format" ]]; then
				Divisor=1024
				Units=("B" "KiB" "MiB" "GiB" "TiB")
			elif [[ "$Req" == format* ]]; then
				Divisor=1000
				Units=("Byte" "Kilo" "Mega" "Giga" "Tera")
			fi

			# Scale down until value fits current unit or max unit is reached
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

	# --- Cryptographic Hash Keywords ---
	md5 | md5sum)
		Get_MD5Sum "$File"
		;;
	sha)
		Get_SHA_Keys shasum "$File"
		;;
	sha1 | sha224 | sha256 | sha384 | sha512)
		Get_SHA_Keys "${Req}sum" "$File"
		;;
	shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum)
		Get_SHA_Keys "$Req" "$File"
		;;

	# --- Random Number Generator ---
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

	# --- Fallback for Unrecognized Keywords ---
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}

# ==============================================================================
# 7. TERMINAL UI HELPERS
# ==============================================================================

# Print a full-width horizontal divider line matching current terminal columns.
Draw_Line() {
	local Width Symbol

	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80} # Default to 80 columns if running non-interactively
	Symbol=${1:-=}

	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
}

# ==============================================================================
# 8. CLI ARGUMENT PARSING & VALIDATION
# ==============================================================================

declare -a InputItems=()

# Separate CLI flags from target file/directory paths in a single pass.
# Doing this upfront prevents flags passed at the end of a command from being
# missed during early iterations or misread during recursion.
Parse_Arguments() {
	local Argument

	for Argument in "$@"; do
		case "${Argument,,}" in
		# Shorthand operational modes
		--copy) Mode="copy" ;;
		--move) Mode="move" ;;
		--delete) Mode="delete" ;;
		--remove) Mode="remove" ;;
		--trash) Mode="trash" ;;
		--shred) Mode="shred" ;;

		# Explicit operational mode
		--mode=*)
			Mode=${Argument#*=}
			Mode=${Mode,,}
			;;

		# Filters & recursion
		--type=*) Type=${Argument#*=} ;;
		--recursive) Recursive="yes" ;;
		--pause=*) Pause=${Argument#*=} ;;

		# Path & filename templates
		--dirs=*) Dirs=${Argument#*=} ;;
		--subdirs=*) SubDirs=${Argument#*=} ;;
		--rename=*) Rename=${Argument#*=} ;;
		--extension=*) Extension=${Argument#*=} ;;
		--title) Title="yes" ;;
		--replace) Replace="yes" ;;

		# Legacy compatibility flags
		--jobs=*) MAX_JOBS=${Argument#*=} ;;
		--compare) Compare="yes" ;;

		# Catch unrecognized flags
		--*)
			printf '%bWARNING:%b Unknown option: %s (ignored)\n' \
				"$YELLOW" "$RESET" "$Argument"
			;;

		# Everything else is queued as a target file or directory
		*)
			InputItems+=("$Argument")
			;;
		esac
	done
}

# Verify option values and on-demand binary requirements before execution.
Validate_Options() {
	# Ensure Mode is recognized
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf '%bERROR:%b Unsupported mode: %s\n' "$RED" "$RESET" "$Mode"
		return 1
		;;
	esac

	# Ensure --pause is a valid integer or decimal number
	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf '%bERROR:%b --pause must be a non-negative number of seconds.\n' \
			"$RED" "$RESET"
		return 1
	fi

	# Warn user about legacy flags that have no active implementation
	[[ -n "$MAX_JOBS" && "$MAX_JOBS" != 4 ]] &&
		printf '%bWARNING:%b --jobs is currently not implemented.\n' "$YELLOW" "$RESET"

	[[ "$Compare" == "yes" ]] &&
		printf '%bWARNING:%b --compare is currently not implemented.\n' "$YELLOW" "$RESET"

	# Check optional external utilities required for destructive modes
	if [[ "$Mode" == "trash" ]] && ! command -v trash-put >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=trash requires trash-put (trash-cli).\n' "$RED" "$RESET"
		return 1
	fi

	if [[ "$Mode" == "shred" ]] && ! command -v shred >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=shred requires shred (coreutils).\n' "$RED" "$RESET"
		return 1
	fi
}

# ==============================================================================
# 9. FILESYSTEM ACTION EXECUTOR
# ==============================================================================

# Execute the chosen operation (copy, move, delete, trash, shred) or print a
# dry-run preview.
#
# CRITICAL SAFETY NOTE:
#   Destructive modes (delete, remove, trash, shred) act on TargetPath rather
#   than SourcePath. If both resolve to the exact same inode/path, the action
#   is blocked to prevent unintended data loss.
Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	# 1. Dry-run preview (default when Mode is empty)
	if [[ -z "$Mode" ]]; then
		printf '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	# 2. Create destination folder hierarchy for copy/move operations
	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}"; then
			printf '%bERROR:%b Could not create destination directory.\n' "$RED" "$RESET"
			return 1
		fi
	fi

	# 3. Same-file safeguard for destructive modes
	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)

		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				printf '%bERROR:%b Source and target are the same file; refusing destructive action: %s\n' \
					"$RED" "$RESET" "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	# 4. Execute requested filesystem operation
	case "$Mode" in
	copy)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			printf '%bERROR:%b Destination already exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		fi
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			printf '%bERROR:%b Destination already exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		fi
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		if [[ -e "$TargetPath" ]]; then
			rm -v -f -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	trash)
		if [[ -e "$TargetPath" ]]; then
			trash-put -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	shred)
		if [[ -e "$TargetPath" ]]; then
			shred -u -n 1 -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	esac
}

# ==============================================================================
# 10. MAIN RECURSIVE FILE PROCESSOR
# ==============================================================================

# Iterate over all provided paths, recursing into directories when enabled,
# resolving target paths/filenames, and delegating execution to Perform_Action.
Sort() {
	local Item
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	# Push a new recursion depth frame onto the progress tracking stack
	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		# Increment and display hierarchical progress (e.g., [1]=2/5 ~ [2]=1/10)
		((Counter[$Current] += 1))
		printf 'PROGRESS'
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		# --- Guard 1: Non-existent path ---
		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		# --- Guard 2: Symbolic links (skipped to prevent infinite loops) ---
		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		# --- Guard 3: Directory traversal ---
		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				# Collect directory contents (nullglob handles empty folders safely)
				Children=("$Item"/*)
				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

				# Clean up source folder after moving files if it is now empty
				if [[ "$Mode" == "move" ]]; then
					rmdir -v -- "$Item" 2>&1
				fi
			else
				printf '%bDIR:%b Skipping (use --recursive): %s\n' \
					"$YELLOW" "$RESET" "$Item"
			fi
			Draw_Line '='
			continue
		fi

		# --- Guard 4: Ignore special devices, sockets, or named pipes ---
		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# ======================================================================
		# REGULAR FILE PROCESSING PIPELINE
		# ======================================================================
		Draw_Line '-'
		printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

		# Step 1: Detect MIME type and split into Category (main) and Subtype
		MIME=$(Get_MIME "$Item")
		MIMEMain=${MIME%%/*}
		MIMESub=${MIME#*/}

		printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

		# Step 2: Apply --type filter if specified by the user
		if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
			printf '%bSKIP:%b MIME type does not match --type=%s\n' \
				"$YELLOW" "$RESET" "$Type"
			Draw_Line '-'
			continue
		fi

		# ----------------------------------------------------------------------
		# Step 3: Construct Destination Directory (--dirs + --subdirs)
		# ----------------------------------------------------------------------
		if [[ -n "$Dirs" ]]; then
			DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
		else
			# Default to the file's current parent directory
			DestinationDir=${Item%/*}
			[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
		fi

		SubDirectory=""
		if [[ -n "$SubDirs" ]]; then
			SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
		fi

		# Combine primary and secondary folders cleanly
		[[ -z "$DestinationDir" ]] && DestinationDir="."
		if [[ -n "$SubDirectory" ]]; then
			DestinationDir="${DestinationDir%/}/$SubDirectory"
		fi

		printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

		# ----------------------------------------------------------------------
		# Step 4: Construct Destination Filename (--rename / --title / --extension)
		# ----------------------------------------------------------------------
		FileName=$(Get_File_Name "$Item")

		# Apply --rename pattern if given
		if [[ -n "$Rename" ]]; then
			TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
			[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
				FileName=$TemporaryName
		fi

		# Apply --title metadata extraction (overrides --rename if successful)
		if [[ "$Title" == "yes" ]]; then
			TemporaryName=""
			case "${MIMEMain,,}" in
			application) TemporaryName=$(Get_Doc_Title "$Item") ;;
			image) TemporaryName=$(Get_Image_Meta "$Item") ;;
			audio) TemporaryName=$(Get_Audio_Info "$Item") ;;
			video) TemporaryName=$(Get_Video_Title "$Item") ;;
			esac

			if [[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]]; then
				FileName=$TemporaryName
			fi
		fi

		# Resolve file extension
		if [[ -n "$Extension" ]]; then
			FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
		else
			FileExtension=$(Get_File_Ext "$Item")
		fi

		# Normalize extension to lowercase and replace MIME slashes with dots
		FileExtension=${FileExtension,,}
		FileExtension=${FileExtension//\//.}

		# Assemble final filename (preserving extensionless files without a trailing dot)
		if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
			NewName="$FileName.$FileExtension"
		else
			NewName=$FileName
		fi

		TargetPath="${DestinationDir%/}/$NewName"
		[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

		# ----------------------------------------------------------------------
		# Step 5: Handle Filename Collisions (when --replace is not active)
		# ----------------------------------------------------------------------
		# Appends -(1), -(2), etc., until a non-conflicting target path is found.
		if [[ "$Mode" == "copy" || "$Mode" == "move" ]] && [[ "$Replace" != "yes" ]]; then
			local CollisionIndex=0
			local TargetBase=$FileName
			local TargetExtension=""

			if [[ "$NewName" == *.* ]]; then
				TargetExtension=".${NewName##*.}"
			fi

			while [[ -e "$TargetPath" ]]; do
				((CollisionIndex += 1))
				NewName="${TargetBase}-(${CollisionIndex})${TargetExtension}"
				TargetPath="${DestinationDir%/}/$NewName"
				[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"
			done
		fi

		printf '%bNEW NAME:%b %s\n' "$YELLOW" "$RESET" "$NewName"
		printf '%bTARGET:%b %s\n' "$YELLOW" "$RESET" "$TargetPath"

		# ----------------------------------------------------------------------
		# Step 6: Execute Action (or Dry-Run Preview) & Optional Pause
		# ----------------------------------------------------------------------
		Perform_Action "$Item" "$TargetPath"

		if [[ -n "$Pause" ]]; then
			sleep "$Pause"
		fi

		Draw_Line '-'
	done

	# Pop the current recursion level off the progress stack
	((Current -= 1))
}

# ==============================================================================
# 11. CLI USAGE & DOCUMENTATION
# ==============================================================================

# Show_Help: show help
Show_Help() {
	Draw_Line '━'

	cat <<'EOF'
Sort.sh v2.1 - Media-Intelligent File Organizer
Organizes files using MIME information, filesystem timestamps and metadata.

USAGE
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

  With no operation mode, the script performs a dry run and only displays
  the planned destination. Files are not changed unless a mode is selected.

OPERATION MODES
  --mode=copy       Copy files to the calculated destination.
  --mode=move       Move files to the calculated destination.
  --mode=delete     Permanently delete the calculated destination file.
  --mode=remove     Alias for --mode=delete.
  --mode=trash      Send the calculated destination file to desktop trash.
  --mode=shred      Run shred -u -n 1 on the calculated destination file.

  Short forms:
  --copy            Same as --mode=copy.
  --move            Same as --mode=move.
  --delete          Same as --mode=delete.
  --remove          Same as --mode=remove.
  --trash           Same as --mode=trash.
  --shred           Same as --mode=shred.

  IMPORTANT:
  delete/remove/trash/shred operate on the calculated TARGET path, not
  automatically on the original source path. If source and target resolve
  to the same file, destructive operations are refused. Review the TARGET
  output carefully before selecting a destructive mode.

FILTERING AND PROCESSING
  --type=VALUE      Process only files whose MIME type contains VALUE.
                    Examples: image, video, audio, pdf, application.
  --recursive       Process files inside supplied directories, including
                    nested directories and hidden files.
  --pause=SECONDS   Wait for the specified number of seconds after each file.

DESTINATION AND NAMING
  --dirs=VALUE      Set the primary destination directory component.
  --subdirs=VALUE   Add a directory component beneath the primary directory.
  --rename=VALUE    Generate a filename (without extension) from VALUE.
  --extension=VALUE Generate the extension from VALUE.
  --title           Try to create the filename from embedded metadata:
                    application: attempts to read a PDF /Title entry
                    image:      uses date_time_original, then filesystem time
                    audio:      combines Artist, Album and Title tags
                    video:      combines Artist and Title tags
                    other:      keeps the original filename
  --replace         Allow copy/move to overwrite an existing destination.
                    Without it, a unique name such as photo-(1).jpg is used.

DYNAMIC VALUES
  Values below can be used with --dirs, --subdirs, --rename and --extension.
  Keywords are case-insensitive.

  DATE AND FILE TIMES
    year              Birth-time year (YYYY); 0000 if unavailable.
    month             Birth-time month (MM); 00 if unavailable.
    day               Birth-time day (DD); 00 if unavailable.
    year+month        Year/month path (YYYY/MM).
    year+month+day    Year/month/day path (YYYY/MM/DD).
    created           Filesystem creation-time string.
    modified          Last modification-time string.
    accessed          Last access-time string.

  FILE IDENTITY
    extension         Original extension.
    mime              Full MIME type, e.g. IMAGE/JPEG.
    mime-main         MIME major type, e.g. IMAGE or VIDEO.
    mime-sub          MIME subtype, e.g. JPEG, MP4 or PDF.
    md5 / md5sum      MD5 checksum.
    sha               SHA checksum using shasum.
    sha1              SHA-1 checksum using sha1sum.
    sha224            SHA-224 checksum using sha224sum.
    sha256            SHA-256 checksum using sha256sum.
    sha384            SHA-384 checksum using sha384sum.
    sha512            SHA-512 checksum using sha512sum.
    shasum            Checksum using shasum.
    sha1deep          Checksum using sha1deep.
    sha256deep        Checksum using sha256deep.
    sha1sum           Checksum using sha1sum.
    sha224sum         Checksum using sha224sum.
    sha256sum         Checksum using sha256sum.
    sha384sum         Checksum using sha384sum.
    sha512sum         Checksum using sha512sum.
    random            One Bash-generated random number.
    randomN           N concatenated random values, e.g. random3.

  SIZE AND MEDIA DIMENSIONS
    size              Images/videos: width x height (e.g. 1920x1080).
                      Other files: decimal file-size unit (B, KB, MB, GB, TB).
    format            Images/videos: resolution tier and orientation.
                      Other files: decimal unit name (Byte, Kilo, Mega, etc.).
    size+format       Images/videos: tier/orientation plus dimensions.
                      Other files: binary unit (B, KiB, MiB, GiB, TiB).
    format+size       Images/videos: tier/orientation plus dimensions.
                      Other files: decimal unit name followed by the value.

  Resolution tiers use the larger dimension:
    TINY, MINI, SMALLER, SMALL, MEDIUM, BIG, BIGGER, HUGE.
  Orientation is SQUARE, WIDE or HIGH.

EXAMPLES
  Preview images grouped by MIME category:
    Sort.sh --dirs=mime-main --type=image ./Downloads/*

  Move videos into year/month folders and use metadata titles:
    Sort.sh --mode=move --dirs=year+month --title --type=video ./Videos/*

  Copy images and use their SHA-256 checksum as the filename:
    Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg

  Organize PDF files by extension and size-unit label:
    Sort.sh --mode=move --dirs=extension --subdirs=format *.pdf

  Preview a destination filename based on the original extension:
    Sort.sh --dirs=mime-main --rename=extension ./Downloads/*

DEPENDENCIES
  Required: Bash, file, coreutils, grep, sed, ffprobe (FFmpeg),
            identify (ImageMagick), and tput (ncurses/terminfo).
  Optional: trash-put for trash mode; shred for shred mode; additional
            checksum programs for the matching checksum keywords.

NOTES AND LIMITATIONS
  * Requires Bash with associative arrays and modern [[ ... ]] syntax.
  * File birth/creation times depend on filesystem support.
  * PDF title extraction is a simple text search, not a complete PDF parser.
  * Metadata extraction is best-effort and depends on the media format.
  * --jobs and --compare are accepted for compatibility but are not implemented.
  * shred cannot guarantee secure erasure on SSDs, snapshots, journals,
    copy-on-write filesystems or storage devices with wear levelling.
  * Always perform a dry run before using move, delete, trash or shred.
EOF

	Draw_Line '━'
}

# ==============================================================================
# 12. SCRIPT ENTRY POINT
# ==============================================================================

# Display help text if invoked with zero arguments.
if (($# == 0)); then
	Show_Help
	exit 0
fi

# Step 1: Parse CLI options and separate them from input paths.
Parse_Arguments "$@"

# Step 2: Validate flags and check mode-specific external tools.
if ! Validate_Options; then
	exit 2
fi

# Step 3: Ensure at least one file or directory path was supplied.
if ((${#InputItems[@]} == 0)); then
	printf '%bERROR:%b No input files or directories were supplied.\n' "$RED" "$RESET"
	exit 2
fi

# Step 4: Run the organizer across all collected input paths.
Sort "${InputItems[@]}"

# Step 5: Print completion banner (the EXIT trap handles final cleanup).
printf '\n%b--- DONE --- %b\n\n' "$GREEN" "$RESET"
echo "Thanks for using HEjder scripts!"
exit 0