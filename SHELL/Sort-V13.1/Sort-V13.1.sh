#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V13.1.sh                                                     #
# Version : 13.1                                                              #
# Desc    : Commented edition of the media-intelligent organizer              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
#
# Sort.sh v3.1 (Commented) - Media-Intelligent File Organizer
# Developed by: HEjder
#
# Purpose:
#   Organize files using MIME types, filesystem timestamps, checksums and
#   optional media metadata. Destination folders and filenames are built
#   from the dynamic values documented in the help text at the end.
#
# Safety:
#   Without an operation mode, this script performs a dry run. It does not
#   copy, move or delete anything unless an explicit mode is selected.
#

# ============================================================================
# 1. TERMINAL COLORS
# ============================================================================

# ANSI escape sequences used by the status messages.
# These are stored as Bash strings and expanded by printf's %b conversion.
BOLD='\e[1m'
BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'

# Bold color aliases are retained for compatibility with earlier versions.
BOLDBLUE='\e[1;34m'
BOLDGREEN='\e[1;32m'
BOLDRED='\e[1;31m'
BOLDYELLOW='\e[1;33m'

# Reset terminal formatting to its normal state.
RESET='\e[0m'

# ============================================================================
# 2. DEPENDENCY CHECK
# ============================================================================

# Map each mandatory external command to the package commonly providing it.
# Bash built-ins such as printf, read, wait and [[ are not listed here.
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

# Optional commands are checked only when their corresponding feature is used:
#   trash-put : --mode=trash
#   shred     : --mode=shred
#   shasum, sha1sum, sha224sum, sha384sum, sha512sum,
#   sha1deep, sha256deep : matching checksum dynamic values.
#
# Check all mandatory commands before doing any work.
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

# Do not continue if a mandatory dependency is missing.
if ((Errors > 0)); then
	printf 'ERROR: %d required command(s) missing; cannot continue.\n' "$Errors"
	exit 1
fi

# ============================================================================
# 3. GLOBAL DEFAULTS AND EXIT HANDLING
# ============================================================================

# Preserve the caller's original field separator. This script does not normally
# change IFS, but restoring it makes the cleanup routine safe for future edits.
OIFS=$IFS

# Default operation: dry run. An action is performed only when Mode is set.
Mode=""

# User-configurable processing options.
Type=""
Recursive="no"
Dirs=""
SubDirs=""
Rename=""
Title=""
Extension=""
Replace="no"
Pause=""

# The old version accepted these two options but did not implement them.
# Keep the variables so the parser can issue an honest warning.
MAX_JOBS=4
Compare="no"

# Track progress independently at each recursive directory depth.
declare -a Total Counter
Current=0

# Cleanup routine used by normal completion and the interrupt handler.
Exit() {
	local Status=${1:-0}

	# Prevent this EXIT handler from recursively invoking itself when exit runs.
	trap - EXIT

	printf 'Waiting for background jobs to finish...\n'
	wait

	# Restore the original shell field separator.
	IFS=$OIFS

	printf 'Finished.\n'
	exit "$Status"
}

# Ctrl+C is converted into a controlled exit so cleanup can run.
Break() {
	printf '\nTerminated by user!\n'
	Exit 130
}

# Run cleanup on normal exit and handle an interactive interrupt.
trap 'Exit $?' EXIT
trap Break INT

# Include hidden files in directory globs and let empty globs expand to nothing.
# This prevents a literal "*.jpg" or ".*" from being treated as a filename.
shopt -s dotglob nullglob

# ============================================================================
# 4. FILE INFORMATION AND CHECKSUM HELPERS
# ============================================================================

# Return the MD5 checksum of a file.
# The first field of md5sum output is the hexadecimal digest.
Get_MD5Sum() {
	local File=$1
	local Sum

	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Run one of the optional checksum programs from /usr/bin.
# The command name is supplied by the dynamic value resolver.
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

# Return a SHA-256 checksum. This helper is retained as a named convenience
# function even though the generic resolver can also call sha256sum directly.
Get_SHA256Sum() {
	local File=$1
	local Sum

	Sum=$(sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Detect a file's MIME type, for example "image/jpeg" or "application/pdf".
Get_MIME() {
	local File=$1
	local MIME

	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	printf '%s' "${MIME:-ERROR}"
}

# Return the filename without its directory and final extension.
# Example: "/tmp/photo.original.jpg" becomes "photo.original".
Get_File_Name() {
	local Name=${1##*/}

	printf '%s' "${Name%.*}"
}

# Return the part of a filename after its final dot.
Get_File_Ext() {
	local BaseName=${1##*/}

	# A name without a dot (or a hidden name such as ".profile") has no
	# extension. Otherwise, return the text following the final dot.
	if [[ "$BaseName" != *.* || "$BaseName" == .* && "$BaseName" != *.*.* ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}

# Return the file size in bytes. Use zero if stat cannot read the file.
Get_File_Size() {
	local File=$1
	local Size

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}

# Return the filesystem birth time as a Unix timestamp.
# GNU stat reports zero when the filesystem does not provide a birth time.
Get_File_Birth() {
	local File=$1
	local Time

	Time=$(stat -c '%W' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Return the human-readable filesystem creation/birth time.
Get_File_Creation_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%w' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Return the file's last-access timestamp.
Get_File_Access_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%x' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Return the file's last-modification timestamp.
Get_File_Modification_Time() {
	local File=$1
	local Time

	Time=$(stat -c '%y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Convert a birth-time timestamp into a requested date component.
# Arguments:
#   $1 = file path
#   $2 = date format, for example +%Y or +%Y/%m
#   $3 = fallback text when the birth time is unavailable
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

# ============================================================================
# 5. IMAGE, VIDEO, AUDIO AND DOCUMENT METADATA
# ============================================================================

# Read image dimensions using ImageMagick.
# The result is formatted as WIDTHxHEIGHT, or 0x0 when unavailable.
Get_Image_WxH() {
	local File=$1
	local Resolution

	Resolution=$(
		identify -ping -format '%wx%h\n' -- "$File" 2>/dev/null |
			head -n 1 |
			tr -d '\r\n '
	)

	printf '%s' "${Resolution:-0x0}"
}

# Read the first video stream's dimensions using ffprobe.
# timeout prevents a damaged or unusual media file from hanging indefinitely.
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

	# ffprobe can append a trailing "x" when one dimension is missing.
	Resolution=${Resolution%x}

	printf '%s' "${Resolution:-0x0}"
}

# Convert a WIDTHxHEIGHT value into a resolution tier and orientation.
# Examples: 1920x1080 -> SMALL/WIDE; 800x1200 -> SMALLER/HIGH.
Get_WxH_Format() {
	local Input=$1
	local Width Height MaxDimension
	local Level="TINY"
	local Aspect="SQUARE"

	# Reject malformed dimension strings before doing numeric comparisons.
	if [[ ! "$Input" =~ ^[0-9]+x[0-9]+$ ]]; then
		printf 'ERROR'
		return 1
	fi

	if [[ "$Input" == "0x0" ]]; then
		printf 'ZERO'
		return 0
	fi

	Width=${Input%%x*}
	Height=${Input##*x}

	# Use the larger side to assign a resolution tier.
	MaxDimension=$Width
	((Height > Width)) && MaxDimension=$Height

	((MaxDimension > 32)) && Level="MINI"
	((MaxDimension > 512)) && Level="SMALLER"
	((MaxDimension > 1024)) && Level="SMALL"
	((MaxDimension > 2048)) && Level="MEDIUM"
	((MaxDimension > 4096)) && Level="BIG"
	((MaxDimension > 8192)) && Level="BIGGER"
	((MaxDimension > 16384)) && Level="HUGE"

	# Describe the image/video orientation.
	((Width > Height)) && Aspect="WIDE"
	((Width < Height)) && Aspect="HIGH"

	printf '%s/%s' "$Level" "$Aspect"
}

# Best-effort extraction of a PDF /Title value.
# This is a lightweight text search, not a full PDF metadata parser.
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

	# Fall back to the existing filename when no title could be extracted.
	[[ -z "$Title" ]] && Title=$(Get_File_Name "$File")

	printf '%s' "${Title:-ERROR}"
}

# Extract the original capture date from image metadata.
# If the tag is absent, use the filesystem creation-time string instead.
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

# Combine the available Artist, Album and Title tags from an audio file.
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

	# Append only tags that were actually found, separating them with " - ".
	[[ -n "$Artist" ]] && Info=$Artist
	[[ -n "$Album" ]] && Info="${Info:+$Info - }$Album"
	[[ -n "$Title" ]] && Info="${Info:+$Info - }$Title"

	# Remove characters that are problematic in common filenames.
	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# Combine the available Artist and Title tags from a video file.
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

	# Remove characters that are problematic in common filenames.
	printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# ============================================================================
# 6. DYNAMIC PATH AND FILENAME VALUE RESOLVER
# ============================================================================

# Resolve a keyword into a value derived from the current file.
#
# Arguments:
#   $1 = dynamic keyword
#   $2 = file path
#
# MIME, MIMEMain and MIMESub are populated by Sort() before this function runs.
Resolve_Path_Segment() {
	local Req=${1,,}
	local File=$2

	case "$Req" in
	# Birth-time date components.
	year)
		Get_Date_Part "$File" '+%Y' '0000'
		;;
	month)
		Get_Date_Part "$File" '+%m' '00'
		;;
	day)
		Get_Date_Part "$File" '+%d' '00'
		;;
	year+month)
		Get_Date_Part "$File" '+%Y/%m' '0000/00'
		;;
	year+month+day)
		Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00'
		;;

	# Original extension and MIME components.
	extension)
		Get_File_Ext "$File"
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

	# Size and format values behave differently for media and other files.
	size | format | size+format | format+size)
		if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
			local Dimensions MediaFormat

			# Images are inspected by identify; videos by ffprobe.
			if [[ "$MIMEMain" == "image" ]]; then
				Dimensions=$(Get_Image_WxH "$File")
			else
				Dimensions=$(Get_Media_WxH "$File")
			fi

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
			# For non-media files, convert the byte count to a unit label.
			local Bytes Value UnitIndex Divisor
			local -a Units

			Bytes=$(Get_File_Size "$File")
			Value=$Bytes
			UnitIndex=0
			Divisor=1000
			Units=("B" "KB" "MB" "GB" "TB" "PB")

			# size+format uses binary units; format values use decimal units.
			if [[ "$Req" == "size+format" ]]; then
				Divisor=1024
				Units=("B" "KiB" "MiB" "GiB" "TiB")
			elif [[ "$Req" == format* ]]; then
				Divisor=1000
				Units=("Byte" "Kilo" "Mega" "Giga" "Tera")
			fi

			# Divide until the value fits the selected unit or units run out.
			while ((Value >= Divisor && UnitIndex < ${#Units[@]} - 1)); do
				((UnitIndex += 1))
				Value=$((Value / Divisor))
			done

			case "$Req" in
			size)
				printf '%s%s' "$Value" "${Units[$UnitIndex]}"
				;;
			size+format)
				printf '%s_%s' "$Value" "${Units[$UnitIndex]}"
				;;
			format)
				printf '%s' "${Units[$UnitIndex]}"
				;;
			format+size)
				printf '%s/%s' "${Units[$UnitIndex]}" "$Value"
				;;
			esac
		fi
		;;

	# Filesystem timestamps.
	created)
		Get_File_Creation_Time "$File"
		;;
	modified)
		Get_File_Modification_Time "$File"
		;;
	accessed)
		Get_File_Access_Time "$File"
		;;

	# Checksums. Some algorithms require optional external programs.
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

	# random returns one Bash random value; randomN concatenates N values.
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

	# Unknown keywords produce an explicit error marker.
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}

# ============================================================================
# 7. TERMINAL DISPLAY HELPERS
# ============================================================================

# Draw a horizontal separator using the current terminal width.
Draw_Line() {
	local Width Symbol

	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	Symbol=${1:-=}

	# Use the requested symbol for every column in the separator.
	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
}

# ============================================================================
# 8. COMMAND-LINE ARGUMENT PARSING
# ============================================================================

# Parse options once, before processing paths. This keeps options from being
# reinterpreted as filenames during recursive directory traversal.
declare -a InputItems=()

# Parse_Arguments: parse arguments
Parse_Arguments() {
	local Argument

	for Argument in "$@"; do
		case "${Argument,,}" in
		# Operation modes: only one mode should normally be supplied.
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

		# Processing and filtering options.
		--type=*) Type=${Argument#*=} ;;
		--recursive) Recursive="yes" ;;
		--pause=*) Pause=${Argument#*=} ;;

		# Destination and naming options.
		--dirs=*) Dirs=${Argument#*=} ;;
		--subdirs=*) SubDirs=${Argument#*=} ;;
		--rename=*) Rename=${Argument#*=} ;;
		--extension=*) Extension=${Argument#*=} ;;
		--title) Title="yes" ;;
		--replace) Replace="yes" ;;

		# Retained legacy switches. They are parsed but not implemented.
		--jobs=*) MAX_JOBS=${Argument#*=} ;;
		--compare) Compare="yes" ;;

		# Any argument not recognized as an option is treated as a path.
		--*)
			printf '%bWARNING:%b Unknown option: %s (ignored)\n' \
				"$YELLOW" "$RESET" "$Argument"
			;;
		*)
			InputItems+=("$Argument")
			;;
		esac
	done
}

# Check that the selected mode is supported before touching any files.
Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf '%bERROR:%b Unsupported mode: %s\n' "$RED" "$RESET" "$Mode"
		return 1
		;;
	esac

	# Validate the pause value as a non-negative numeric duration.
	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf '%bERROR:%b --pause must be a non-negative number of seconds.\n' \
			"$RED" "$RESET"
		return 1
	fi

	# These options existed in the original parser but have no active behavior.
	[[ -n "$MAX_JOBS" && "$MAX_JOBS" != 4 ]] &&
		printf '%bWARNING:%b --jobs is currently not implemented.\n' "$YELLOW" "$RESET"

	[[ "$Compare" == "yes" ]] &&
		printf '%bWARNING:%b --compare is currently not implemented.\n' "$YELLOW" "$RESET"

	# Check mode-specific optional programs only when those modes are requested.
	if [[ "$Mode" == "trash" ]] && ! command -v trash-put >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=trash requires trash-put (trash-cli).\n' "$RED" "$RESET"
		return 1
	fi

	if [[ "$Mode" == "shred" ]] && ! command -v shred >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=shred requires shred (coreutils).\n' "$RED" "$RESET"
		return 1
	fi
}

# ============================================================================
# 9. FILE OPERATION HELPER
# ============================================================================

# Perform the selected operation on the calculated destination path.
#
# IMPORTANT:
#   The legacy behavior operates on TargetPath, not automatically on SourcePath.
#   If source and target resolve to the same file, destructive modes are refused.
Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	# Dry-run mode is the default and never modifies the filesystem.
	if [[ -z "$Mode" ]]; then
		printf '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	# Ensure the destination directory exists for copy and move operations.
	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}"; then
			printf '%bERROR:%b Could not create destination directory.\n' "$RED" "$RESET"
			return 1
		fi
	fi

	# Resolve both paths before destructive operations to avoid acting on the
	# source file by accident when source and destination refer to the same file.
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

	# Execute the selected action. -- prevents paths beginning with "-" from
	# being interpreted as command-line options by the external utility.
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

# ============================================================================
# 10. MAIN FILE PROCESSOR
# ============================================================================

# Process a list of files and directories. Directory traversal calls this
# function recursively when --recursive was selected.
Sort() {
	local Item
	local Directory
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	# Increase recursion depth and initialize this level's progress counters.
	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		# Update progress for the current recursion level.
		((Counter[$Current] += 1))
		printf 'PROGRESS'
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		# Skip paths that do not exist, including broken symbolic links.
		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		# Symbolic links are deliberately skipped to avoid following links
		# outside the requested directory tree or processing the same target twice.
		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		# Directory handling: recurse only when the user supplied --recursive.
		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				# Expand the directory's contents, including hidden files.
				# nullglob ensures an empty directory produces an empty array.
				Children=("$Item"/*)

				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

				# After a move operation, remove the source directory only if
				# it is now empty. rmdir safely refuses non-empty directories.
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

		# Ignore special filesystem objects; this organizer handles regular files.
		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# Start processing a regular file.
		Draw_Line '-'
		printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

		# Read MIME information once and split it into major and minor parts.
		MIME=$(Get_MIME "$Item")
		MIMEMain=${MIME%%/*}
		MIMESub=${MIME#*/}

		printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

		# If --type was provided, the requested text must occur in the MIME type.
		if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
			printf '%bSKIP:%b MIME type does not match --type=%s\n' \
				"$YELLOW" "$RESET" "$Type"
			Draw_Line '-'
			continue
		fi

		# --------------------------------------------------------------------
		# 10a. Build the destination directory
		# --------------------------------------------------------------------

		# --dirs selects the primary directory component. Without it, use the
		# source file's current parent directory.
		if [[ -n "$Dirs" ]]; then
			DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
		else
			DestinationDir=${Item%/*}
			[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
		fi

		# --subdirs adds one more level beneath the primary directory.
		SubDirectory=""
		if [[ -n "$SubDirs" ]]; then
			SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
		fi

		# Assemble the final destination directory, avoiding empty components.
		if [[ -z "$DestinationDir" ]]; then
			DestinationDir="."
		fi
		if [[ -n "$SubDirectory" ]]; then
			DestinationDir="${DestinationDir%/}/$SubDirectory"
		fi

		printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

		# --------------------------------------------------------------------
		# 10b. Build the destination filename
		# --------------------------------------------------------------------

		# Start with the original basename; --rename can replace it with a
		# dynamic value such as sha256sum, year or random.
		FileName=$(Get_File_Name "$Item")
		if [[ -n "$Rename" ]]; then
			TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
			[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
				FileName=$TemporaryName
		fi

		# --title takes precedence over --rename when metadata is available.
		if [[ "$Title" == "yes" ]]; then
			TemporaryName=""
			case "${MIMEMain,,}" in
			application)
				TemporaryName=$(Get_Doc_Title "$Item")
				;;
			image)
				TemporaryName=$(Get_Image_Meta "$Item")
				;;
			audio)
				TemporaryName=$(Get_Audio_Info "$Item")
				;;
			video)
				TemporaryName=$(Get_Video_Title "$Item")
				;;
			esac

			# Do not replace the filename with an empty or error result.
			if [[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]]; then
				FileName=$TemporaryName
			fi
		fi

		# Use the original extension unless --extension supplied a replacement.
		if [[ -n "$Extension" ]]; then
			FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
		else
			FileExtension=$(Get_File_Ext "$Item")
		fi

		# Normalize the extension and replace a MIME slash with a dot.
		FileExtension=${FileExtension,,}
		FileExtension=${FileExtension//\//.}

		# Assemble the destination filename. A file with no extension is kept
		# extensionless instead of receiving an artificial trailing dot.
		if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
			NewName="$FileName.$FileExtension"
		else
			NewName=$FileName
		fi

		TargetPath="${DestinationDir%/}/$NewName"
		[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

		# --------------------------------------------------------------------
		# 10c. Avoid accidental name collisions for copy/move
		# --------------------------------------------------------------------

		# When --replace is absent, find the first unused "name-(N).ext".
		# This check applies only to copy and move, not destructive modes.
		if [[ "$Mode" == "copy" || "$Mode" == "move" ]] &&
			[[ "$Replace" != "yes" ]]; then
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

		# --------------------------------------------------------------------
		# 10d. Perform the requested action, or show a dry-run preview
		# --------------------------------------------------------------------

		Perform_Action "$Item" "$TargetPath"

		# Optional pause between files, useful when watching terminal output.
		if [[ -n "$Pause" ]]; then
			sleep "$Pause"
		fi

		Draw_Line '-'
	done

	# Decrease the recursion depth when this directory level has completed.
	((Current -= 1))
}

# ============================================================================
# 11. HELP TEXT
# ============================================================================

# Display the complete usage guide when no file or directory arguments exist.
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

# ============================================================================
# 12. SCRIPT ENTRY POINT
# ============================================================================

# No arguments means the user requested the help screen.
if (($# == 0)); then
	Show_Help
	exit 0
fi

# Parse options and collect the remaining arguments as input paths.
Parse_Arguments "$@"

# Validate the selected mode and any mode-specific requirements.
if ! Validate_Options; then
	exit 2
fi

# At least one path must remain after command-line options are removed.
if ((${#InputItems[@]} == 0)); then
	printf '%bERROR:%b No input files or directories were supplied.\n' "$RED" "$RESET"
	exit 2
fi

# Process the requested paths.
Sort "${InputItems[@]}"

# Print a final status banner; the EXIT trap performs the cleanup.
printf '\n%b--- DONE --- %b\n\n' "$GREEN" "$RESET"
echo "Thanks for using HEjder scripts!"
exit 0