#!/bin/bash
# Sort.sh v2.2 - Media-Intelligent File Organizer
# Developed by: Ali_ISIN
# Function: Organizes files based on MIME type, metadata, and user-defined path patterns.
#
# Notes for maintainers:
# - The code-flow is intentionally kept simple: check tools -> define helpers -> parse arguments -> recurse -> process files.
# - Most decisions are made inside Sort(), because command-line options and file-processing state are handled together.
# - MIME-related globals (MIME, MIMEMain, MIMESub) are refreshed for every file before Resolve_Path_Segment() is called.
# - This version adds explanatory comments and more terminal output, but does not redesign the original control flow.



# --- Program Information ---
# Keep these values in one place so Usage(), Manual(), and Version() stay consistent.
PROGRAM="Sort.sh"
VERSION="2.2"
AUTHOR="Ali_ISIN"
LICENSE="Open Source"
DESCRIPTION="Media-Intelligent File Organizer"

# --- Colors & UI Styling ---
# Defining ANSI escape sequences for text formatting in the terminal.
BOLD='\e[1m'       # Bold text
BLUE='\e[34m'      # Standard Blue
GREEN='\e[32m'     # Standard Green
RED='\e[31m'       # Standard Red
YELLOW='\e[33m'    # Standard Yellow

# High-intensity bold variants for headers and important labels.
BOLDBLUE='\e[34m'
BOLDGREEN='\e[32m'
BOLDRED='\e[31m'
BOLDYELLOW='\e[33m'

RESET='\e[0m'      # Resets the terminal color to default.

# --- Human-readable Output Icons ---
# These symbols make long recursive runs easier to scan visually.
# If your terminal does not support emoji, the text labels still explain the status.
ICON_INFO="ℹ️"
ICON_OK="✅"
ICON_WARN="⚠️"
ICON_ERROR="❌"
ICON_SKIP="⏭️"
ICON_DIR="📁"
ICON_FILE="📄"
ICON_LINK="🔗"
ICON_COPY="📋"
ICON_MOVE="🚚"
ICON_REMOVE="🗑️"
ICON_TEST="🧪"
ICON_MIME="🏷️"
ICON_TARGET="🎯"
ICON_NAME="📝"
ICON_CREATE="📂"
ICON_CLEAN="🧹"
ICON_PROGRESS="📊"
ICON_PAUSE="⏸️"
ICON_DONE="🏁"
ICON_SEARCH="🔍"
ICON_HASH="🔑"
ICON_OPTION="⚙️"
ICON_MANUAL="📘"
ICON_USAGE="📚"
ICON_VERSION="ℹ️"


# --- 1. Check Requirements ---
# Associative array mapping required binaries to their respective software packages.
declare -A Required=(
	[file]='Linux Base' [stat]='Linux Base' [cp]='Linux Base'
	[mv]='Linux Base' [rm]='Linux Base' [find]='Linux Base'
	[sha256sum]='Linux Base' [md5sum]='Linux Base' [ffprobe]='FFMPEG'
)

# Loop through the required commands to ensure they are installed in the system PATH.
for Key in "${!Required[@]}"; do
	if ! command -v "$Key" &> /dev/null; then
		# If a command is missing, notify the user and provide the package name.
		printf "$ICON_ERROR $RED ERROR:$RESET missing command '%s' | install package: %s\n" "$Key" "${Required[$Key]}"
		exit 10
	fi
done

# --- 2. Setup & Safety ---
OIFS=$IFS # Save the Original Internal Field Separator to restore on exit.

# Function to handle clean exit if the user interrupts the script (Ctrl+C).
function Break {
	IFS=$OIFS;
	printf "\n$ICON_WARN Interrupted: terminated by user.\n";
	exit 1;
}
trap Break INT       # Traps the SIGINT signal.
shopt -u dotglob     # Default: wildcards do NOT include hidden files. Use --hidden to enable them during recursion.

# --- Helper Functions ---

# Generates an MD5 hash of the file content.
# Useful for shorter hash-based filenames than SHA256.
function Get_MD5Sum { md5sum -b "$1" | cut -d' ' -f1; }

# Generates a SHA256 hash of the file content for unique identification.
function Get_SHA256Sum { printf "%s" "$(sha256sum -b "$1" | cut -d' ' -f1)"; }

# Detects the MIME type (e.g., image/jpeg) using the 'file' utility.
function Get_MIME      { printf "%s" "$(file -b --mime-type "$1" 2>/dev/null)"; }

# Extracts the filename without the path and without the last extension.
function Get_File_Name {
	local b=$(basename "$1")
	printf "%s" "${b%.*}"
}

# Extracts just the file extension (everything after the last dot).
function Get_File_Ext  { printf "%s" "${1##*.}"; }

# Gets the file size in bytes using 'stat'. Defaults to 0 if the file is inaccessible.
function Get_File_Size {
	local S=$(stat -c %s "$1" 2>/dev/null)
	printf "%d" "${S:-0}"
}

# Gets the file birth (creation) time as a Unix timestamp.
function Get_File_Birth {
	local B=$(stat -c %W "$1" 2>/dev/null)
	printf "%s" "${B:-0}"
}

# Detailed 'stat' functions for various timestamps (Creation, Access, Modification).
function Get_File_Creation_Time {
    printf "%s" "$(stat -c %w "$1" 2>/dev/null)"
}

function Get_File_Access_Time {
    printf "%s" "$(stat -c %x "$1" 2>/dev/null)"
}

function Get_File_Modification_Time {
    printf "%s" "$(stat -c %y "$1" 2>/dev/null)"
}

# Converts a birth timestamp into a specific date part (Year, Month, etc.) using 'date'.
function Get_Date_Part {
	local T=$(Get_File_Birth "$1")
	[ "$T" != "0" ] && date -d "@$T" "$2" 2>/dev/null || printf "$3"
}

# Image Metadata: Retrieves Width x Height resolution using ffprobe.
# The same ffprobe method is used for both images and videos when ffprobe can read the stream metadata.
function Get_Image_WxH {
	local res=$(timeout 10s ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null)
	printf "${res:-0x0}"
}

# Video Metadata: Retrieves resolution via FFmpeg's 'ffprobe'.
function Get_Video_WxH {
	local res=$(timeout 10s ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null)
	printf "${res:-0x0}"
}

# Logic to categorize resolutions into human-readable tiers (SMALL, MEDIUM, BIG) and aspect ratios.
function Get_WxH_Format {
	[[ ! "$1" =~ [0-9]+x[0-9]+ ]] && { printf "ERROR"; return; }
	[ "$1" == "0x0" ] && { printf "ZERO"; return; }
	
	local W=${1%%x*} H=${1##*x}
	local MAX=$W
	[ "$H" -gt "$W" ] && MAX=$H
	local L="HUGE"
	if [ "$W" -eq 0 ];   then L="ZERO"
	elif [ "$MAX" -lt 512 ];  then L="SMALLER"
	elif [ "$MAX" -lt 1024 ]; then L="SMALL"
	elif [ "$MAX" -lt 2048 ]; then L="MEDIUM"
	elif [ "$MAX" -lt 4096 ]; then L="BIG"
	elif [ "$MAX" -lt 8096 ]; then L="BIGGER"
	fi
	local A="SQUARE"
	if [ "$W" -gt "$H" ]; then
		A="WIDE"
	elif [ "$W" -lt "$H" ]; then
		A="HIGH"
	fi
	printf "$L/$A"
}

# PDF Document Helper: Scans internal PDF stream for the '/Title' tag using grep.
function Get_Doc_Title {
    local title=$(grep -a "/Title" "$1" | head -n 1 | sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_')
    if [ -z "$title" ]; then
        Get_File_Name "$1"
    else
        echo "$title"
    fi
}

# Image Metadata Helper: Extracts Camera Make and Model tags.
function Get_Image_Meta {
    local model=$(timeout 5s ffprobe -v error -show_entries format_tags=make,model -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | tr '\n' ' ')
    if [ -z "$model" ] || [ "$model" = " " ]; then
        Get_File_Name "$1"
    else
        echo "$model" | tr -d '/\\:*?"<>|' | tr ' ' '_'
    fi
}

# Audio Metadata Helper: Uses ffprobe to extract Artist and Title tags for naming.
function Get_Audio_Info {
    local info=$(timeout 5s ffprobe -v error -show_entries format_tags=artist,title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | tr '\n' '-' | sed 's/-$//')
    if [ -z "$info" ]; then
        Get_File_Name "$1"
    else
        echo "$info" | tr -d '/\\:*?"<>|' | tr ' ' '_'
    fi
}

# Video Metadata Helper: Extracts internal 'title' tag from video containers.
function Get_Video_Title {
    local title=$(timeout 10s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null)
    if [ -z "$title" ]; then
        Get_File_Name "$1"
    else
        # Clean title: Remove characters that are illegal in filenames and swap spaces for underscores.
        echo "$title" | tr -d '/\\:*?"<>|' | tr ' ' '_'
    fi
}

# Master Path Resolver: Converts dynamic keywords (like 'year' or 'size') into actual file attributes.
function Resolve_Path_Segment {
	# Req is lowercased so options like YEAR, Year, and year behave the same.
	# File is the current source file. Res is the resolved replacement value.
	local Req="${1,,}" File="$2" Res=""
	case "$Req" in
		# Date-based virtual values. These are mostly used for folder structures.
		"year")           Res=$(Get_Date_Part "$File" "+%Y" "0000") ;;
		"month")          Res=$(Get_Date_Part "$File" "+%m" "00") ;;
		"day")            Res=$(Get_Date_Part "$File" "+%d" "00") ;;
		"year+month")     Res=$(Get_Date_Part "$File" "+%Y/%m" "0000/00") ;;
		"year+month+day") Res=$(Get_Date_Part "$File" "+%Y/%m/%d" "0000/00/00") ;;
		# Identity-based values. Folder output is uppercased later, so extension is uppercased here too.
		"extension")      local e=$(Get_File_Ext "$File"); Res=${e^^} ;; # Forces extension to uppercase.
		"mime")           Res=${MIME^^} ;;
		"mime-main")      Res=${MIMEMain^^} ;;
		"mime-sub")       Res=${MIMESub^^} ;;
		"size"|"format"|"size+format"|"format+size")
			# Context-aware sizing: Media files get resolution/tier, other files get byte-size labels.
			if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
				local WxH=$([ "$MIMEMain" == "image" ] && Get_Image_WxH "$File" || Get_Video_WxH "$File"); WxH=${WxH%x}
				local Fmt=$(Get_WxH_Format "$WxH")
				[[ "$Req" == "size" ]] && Res="$WxH" || { [[ "$Req" == "format" ]] && Res="$Fmt" || Res="$Fmt/$WxH"; }
			else
				# General file size formatting (B, KB, MB, etc.)
				local S=$(Get_File_Size "$File")
				S=${S:-0}
				local T=$S N=0 Div=1000

				local U=("B" "KB" "MB" "GB" "TB" "PB")

				# Logic for Binary units (KiB, MiB) vs Decimal units.
				if [[ "$Req" == "size+format" ]] ; then
					Div=1024
					U=("B" "KiB" "MiB" "GiB" "TiB")
				elif [[ "$Req" == "format"* ]] ; then
					Div=1000
					U=("Byte" "Kilo" "Mega" "Giga" "Tera")
				fi

				# Loop to divide the size until it reaches the appropriate unit.
				while [ "$T" -gt "$((Div-1))" ] && [ "$N" -lt "5" ]; do ((N++)); T=$((T/Div)); done

				case "$Req" in
					"size") Res="$T${U[$N]}" ;;
					"size+format") Res="${T}_${U[$N]}" ;;
					"format") Res="${U[$N]}" ;;
					"format+size") Res="${U[$N]}/$T" ;;
				esac
			fi ;;
		# Full timestamp values from stat. Exact format depends on GNU stat and filesystem support.
		"created") Res=$(Get_File_Creation_Time "$File") ;;
		"modified") Res=$(Get_File_Modification_Time "$File") ;;
		"accessed") Res=$(Get_File_Access_Time "$File") ;;
		# Hash-based values. Good for deduplication and stable generated filenames.
		"md5") Res=$(Get_MD5Sum "$File") ;;
		"shasum"|"sha1deep"|"sha1sum"|"sha224sum"|"sha256deep"|"sha256sum"|"sha384sum"|"sha512sum")
			# Execute the system hashing tool matching the keyword.
			Res=$(/usr/bin/$Req -b "$File" | cut -d' ' -f1) ;;
		"random") Res="${RANDOM}${RANDOM}" ;; # Generates a random numeric string.
		*) Res="$1" ;; # If no keyword matches, use the input literally.
	esac
	printf "$Res"
}

# UI Tool: Creates a horizontal rule based on the current terminal width.
function Draw_Line {
	local w=$(tput cols) s="${1:-=}"
	printf -v l "%${w}s" ""
	echo "${l// /$s}" | cut -c 1-"$w"
}


# Cleanup helper: removes a source directory only when it is truly empty.
# This is used after recursive move operations, so folders left empty by moved files
# are cleaned up safely. Non-empty folders are kept. Symbolic-link directories are
# not removed here, because removing a link is different from removing a real dir.
function Remove_Empty_Source_Directory {
	local Dir="$1"

	# Nothing to clean when the path is not an existing real directory.
	[ -d "$Dir" ] || return 0
	[ -L "$Dir" ] && { printf "$ICON_LINK $YELLOW CLEANUP:$RESET keeping symlink directory: %s\n" "$Dir"; return 0; }

	# rmdir is intentionally used instead of rm -r. It can only remove empty dirs.
	if rmdir -v "$Dir" >/tmp/sort_cleanup_$$.log 2>&1; then
		printf "$ICON_CLEAN $BLUE CLEANUP:$RESET removed empty directory: %s\n" "$Dir"
	else
		# This is not a fatal error. It usually means files were filtered out, hidden
		# files remain, or the directory was not fully emptied by the move operation.
		printf "$ICON_INFO $YELLOW CLEANUP:$RESET kept non-empty directory: %s\n" "$Dir"
	fi
	rm -f /tmp/sort_cleanup_$$.log
}

# --- Main Logic ---

# Global arrays to track progress across multiple recursion levels.
declare -a Total Counter
Current=0

# The core recursive function that handles the actual sorting of files and directories.
function Sort {
	((Current++))
	Total[$Current]=$#      # Track how many items were passed to the current call.
	Counter[$Current]=0     # Initialize current progress to zero.

	for Item in "$@"; do
		# Each argument is checked first as an option. Anything that is not an option is treated as a path.
		case "${Item,,}" in
			# Parsing CLI Arguments.
			"--pause="*)     ((Total[$Current]--)); Pause=${Item#*=}; printf "$ICON_OPTION $BLUE OPTION:$RESET pause=%s seconds\n" "$Pause";;
			"--type="*)      ((Total[$Current]--)); Type=${Item#*=}; printf "$ICON_OPTION $BLUE OPTION:$RESET type filter=%s\n" "$Type";;
			"--mode="*)      ((Total[$Current]--)); Mode=${Item#*=}; printf "$ICON_OPTION $BLUE OPTION:$RESET mode=%s\n" "$Mode";;
			"--recursive")   ((Total[$Current]--)); Recursive="yes"; printf "$ICON_OPTION $BLUE OPTION:$RESET recursive=yes\n";;
			"--links")       ((Total[$Current]--)); Links="yes"; printf "$ICON_LINK $BLUE OPTION:$RESET links=yes symbolic links will be processed\n";;
			"--hidden")      ((Total[$Current]--)); Hidden="yes"; shopt -s dotglob; printf "$ICON_OPTION $BLUE OPTION:$RESET hidden=yes hidden files are included during script-side expansion\n";;
			"--usage")       ((Total[$Current]--)); Usage; exit 0;;
			"--version")     ((Total[$Current]--)); Version; exit 0;;
			"--manuel"|"--manual") ((Total[$Current]--)); Manual; exit 0;;
			"--replace")     ((Total[$Current]--)); Replace="yes"; printf "$ICON_WARN $BLUE OPTION:$RESET replace=yes existing targets may be overwritten\n";;
			"--rename="*)    ((Total[$Current]--)); Rename=${Item#*=}; printf "$ICON_NAME $BLUE OPTION:$RESET rename pattern=%s\n" "$Rename";;
			"--title")       ((Total[$Current]--)); Title="yes"; printf "$ICON_SEARCH $BLUE OPTION:$RESET title extraction=yes\n";;
			"--extension="*) ((Total[$Current]--)); Extension=${Item#*=}; printf "$ICON_NAME $BLUE OPTION:$RESET extension pattern=%s\n" "$Extension";;
			"--dirs="*)      ((Total[$Current]--)); Dirs=${Item#*=}; printf "$ICON_DIR $BLUE OPTION:$RESET primary dirs pattern=%s\n" "$Dirs";;
			"--subdirs="*)   ((Total[$Current]--)); SubDirs=${Item#*=}; printf "$ICON_DIR $BLUE OPTION:$RESET secondary dirs pattern=%s\n" "$SubDirs";;
			*)
			# Incremental progress tracking output for the UI.
			((Counter[$Current]++))
			printf "$ICON_PROGRESS PROGRESS"
			for (( i=1; i<=$Current; i++ )); do printf " ~ [$i]=${Counter[$i]}/${Total[$i]}"; done; printf "\n"

			# Basic sanity checks.
			# Symbolic links are skipped by default to avoid accidental loops or touching linked targets.
			# Use --links when you explicitly want symlinked files/directories to be handled.
			if [[ -L "$Item" && "$Links" != "yes" ]]; then printf "$ICON_SKIP SKIP: Symlink %s  (use --links to process symbolic links)\n" "$Item"
			elif [[ ! -e "$Item" && ! -L "$Item" ]]; then printf "$ICON_SKIP SKIP: Missing %s\n" "$Item"
			elif [[ -d "$Item" ]]; then
				# If the current item is a Directory.
				Draw_Line "="
				if [ "$Recursive" = "yes" ]; then
					printf "$ICON_DIR $BOLDBLUE DIRECTORY:$YELLOW %s$RESET\n" "$Item"
					Draw_Line ">"
					Sort "$Item"/* # RECURSIVE STEP: Enter directory and call Sort again.
					# After returning from a recursive move, remove the source directory
					# only if it is empty. This keeps non-empty directories safe.
					if [ "$Mode" = "move" ]; then
						Remove_Empty_Source_Directory "$Item"
					fi
				else
					printf "$ICON_SKIP $RED DIRECTORY:$RESET skipping because --recursive is not enabled.\n"
				fi
				Draw_Line "="
			elif [[ -f "$Item" ]]; then
				# If the current item is a File.
				Draw_Line "-"
				printf "$ICON_FILE $BOLDGREEN FILE:$YELLOW %s$RESET\n" "$Item"

				# Pre-calculate MIME and sub-MIME types.
				MIME=$(Get_MIME "$Item")
				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}
				printf "$ICON_MIME $YELLOW MIME:$RESET %s\n" "$MIME"

				# Filter check: Process only if no type filter is set, or if the file MIME matches.
				if [ -z "$Type" ] || [[ "${MIME^^}" == *"${Type^^}"* ]]; then

					# Step 1: Construct the Target Path using user-defined patterns.
					printf "$ICON_SEARCH $YELLOW RESOLVE:$RESET dirs=\"%s\" subdirs=\"%s\"\n" "$Dirs" "$SubDirs"
					D=$(Resolve_Path_Segment "$Dirs" "$Item")
					SD=$([ -n "$SubDirs" ] && Resolve_Path_Segment "$SubDirs" "$Item" || printf "")

					Loc="."
					[ -n "$D" ] && Loc="${D^^}"
					[ -n "$SD" ] && Loc="$Loc/${SD^^}"

					printf "$ICON_TARGET $YELLOW TARGET:$RESET %s\n" "$Loc"

					# Step 2: Build the Target Filename.
					Name=""
					# If --title flag is set, attempt to pull metadata based on the file type.
					if [ -n "$Title" ] ; then
						case "${MIMEMain,,}" in
						"application") Name=$(Get_Doc_Title "$Item");;
						"image")       Name=$(Get_Image_Meta "$Item");;
						"audio")       Name=$(Get_Audio_Info "$Item");;
						"video")       Name=$(Get_Video_Title "$Item");;
						esac
					fi

					# Fallback to the original filename if no title was extracted or requested.
					[ -z "$Name" ] && Name=$(Get_File_Name "$Item")
					printf "$ICON_NAME $YELLOW BASE-NAME:$RESET %s\n" "$Name"

					# Override name if a specific --rename pattern was provided.
					[ -n "$Rename" ] && { printf "$ICON_NAME $YELLOW RENAME:$RESET resolving pattern %s\n" "$Rename"; Name=$(Resolve_Path_Segment "$Rename" "$Item"); }

					# Handle extension renaming or default extension extraction.
					Ext=$(Get_File_Ext "$Item")
					printf "$ICON_NAME $YELLOW EXTENSION:$RESET original=%s\n" "$Ext"
					if [ -n "$Extension" ]; then
						Ext=$(Resolve_Path_Segment "$Extension" "$Item")
						Ext=${Ext,,} # Normalize extension to lowercase.
						Ext=${Ext//\//.} # Safety: replace slashes with dots.
						Ext=${Ext// /_}  # Safety: replace spaces with underscores.
						printf "$ICON_NAME $YELLOW EXTENSION:$RESET resolved=%s\n" "$Ext"
					fi

					# Step 3: Collision Management.
					NewName="$Name.$Ext"
					
					# If not in 'replace' mode, find a unique name (e.g. file-(1).jpg) if target exists.
					if [ -z "$Replace" ]; then
						printf "$ICON_SEARCH $YELLOW COLLISION:$RESET replace=no, checking for an unused target filename\n"
						local C=0
						BaseName="$Name"
						while [ -e "$Loc/$NewName" ]; do
							((C++))
							NewName="$BaseName-($C).$Ext"
						done
					fi
					
					printf "$ICON_NAME $YELLOW NEW-NAME:$RESET %s\n" "$NewName"

					# Step 4: Perform the Action (Move, Copy, or Trash).
					if [ -n "$Mode" ]; then
						printf "$ICON_TARGET $YELLOW ACTION:$RESET mode=%s\n  source: %s\n  target: %s\n" "$Mode" "$Item" "$Loc/$NewName"
						# Ensure target directory structure exists.
						printf "$ICON_CREATE $YELLOW MKDIR:$RESET %s\n" "$(mkdir -v -p "$Loc")"

						case "$Mode" in
							"move")   printf "$ICON_MOVE $RED MOVE:$RESET %s\n"   "$(mv -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
							"copy")   printf "$ICON_COPY $RED COPY:$RESET %s\n"   "$(cp -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
							"remove") printf "$ICON_REMOVE $RED REMOVE:$RESET %s\n" "$(trash-put -v "$Item" 2>&1)" ;;
						esac
					else
						# Dry Run Mode: Show user what would happen without making changes.
						printf "$ICON_TEST $GREEN DRY-RUN:$RESET would place\n  source: %s\n  target: %s\n" "$Item" "$Loc/$NewName"
					fi

					# Optional pause to slow down execution for visual monitoring.
					[ -n "$Pause" ] && { printf "$ICON_PAUSE $YELLOW PAUSE:$RESET sleeping %s seconds\n" "$Pause"; sleep "$Pause"; }

					Draw_Line "-"
				else
					printf "$ICON_SKIP $YELLOW FILTER:$RESET skipped because MIME %s does not match requested type %s\n" "$MIME" "$Type"
				fi
			fi ;;
		esac
	done
	((Current--)) # Level finished, pop back up to the parent directory level.
}

# --- Usage / Manual Output ---
# Usage() is intentionally short. It is shown when the script is started without arguments.
# Manual() is intentionally long. It works as the built-in manual for this script.
function Usage {
	Draw_Line "━"
	cat << EOF
	${ICON_USAGE} ${PROGRAM} v${VERSION} | ${DESCRIPTION}
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Developed by: ${AUTHOR}

	USAGE:
	  Sort.sh [OPTIONS] FILE...
	  Sort.sh [OPTIONS] DIRECTORY...
	  Sort.sh --usage
	  Sort.sh --manual

	SAFE DEFAULT:
	  When --mode is not used, the script runs in TEST mode.
	  It prints what would happen, but does not copy, move, or remove files.

	COMMON OPTIONS:
	  --mode=copy        Copy files into the generated target path.
	  --mode=move        Move files into the generated target path.
	  --mode=remove      Send files to trash using trash-put.
	  --type=VALUE       Process only matching MIME types, for example image, video, audio, pdf.
	  --recursive        Enter directories and process their contents.
	  --links            Process symbolic links instead of skipping them.
	  --hidden           Include hidden files during script-side directory expansion.
	  --replace          Overwrite existing target files instead of creating name-(N).ext.
	  --title            Try to build names from metadata.
	  --pause=SEC        Pause between processed files.

	ORGANIZATION OPTIONS:
	  --dirs=VALUE       Main target directory pattern.
	  --subdirs=VALUE    Secondary target directory pattern.
	  --rename=VALUE     Filename pattern.
	  --extension=VALUE  Extension pattern.

	DYNAMIC VALUES:
	  year month day year+month year+month+day
	  created modified accessed
	  mime mime-main mime-sub extension
	  size format size+format format+size
	  md5 sha1sum sha224sum sha256sum sha384sum sha512sum random

	EXAMPLES:
	  Sort.sh *
	  Sort.sh --recursive --hidden ~/Downloads
	  Sort.sh --mode=move --type=image --dirs=year+month --subdirs=format ~/Pictures
	  Sort.sh --mode=copy --links --rename=sha256sum --extension=mime-sub *

	MORE HELP:
	  Sort.sh --manual      Show the extended manual with notes and limitations.
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
	Draw_Line "━"
}

function Manual {
	Draw_Line "━"
	cat << EOF
	${ICON_MANUAL} ${PROGRAM} v${VERSION} Manual | ${DESCRIPTION}
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

	1. PURPOSE
	   Sort.sh organizes files by building a target path from file information.
	   It can use MIME type, dates, file size, media resolution, hashes, metadata,
	   and user-defined path patterns.

	2. BASIC SYNTAX
	   Sort.sh [OPTIONS] FILE...
	   Sort.sh [OPTIONS] DIRECTORY...

	   Examples:
	     Sort.sh *
	     Sort.sh ~/Downloads/*
	     Sort.sh --recursive ~/Downloads
	     Sort.sh --mode=move --dirs=mime-main --subdirs=mime-sub *

	3. SAFE TEST MODE
	   If --mode is omitted, no files are changed.
	   The script only prints the source and generated destination.

	   Example:
	     Sort.sh --dirs=mime-main --rename=sha256sum *

	4. OPERATION MODES
	   --mode=copy
	       Copy files to the generated target path.

	   --mode=move
	       Move files to the generated target path.
	       After recursive moves, the script tries to remove empty source directories.

	   --mode=remove
	       Send files to trash using trash-put.
	       Note: trash-put must be installed separately on systems that do not ship it.

	5. FILTERING
	   --type=VALUE
	       Process only files whose MIME type contains VALUE.
	       Matching is case-insensitive.

	   Examples:
	     --type=image
	     --type=video
	     --type=audio
	     --type=application/pdf
	     --type=jpeg
	     --type=text

	6. DIRECTORY PROCESSING
	   --recursive
	       Enter directories and process their contents.

	   Without --recursive:
	       Directory arguments are displayed and skipped.

	7. SYMBOLIC LINKS
	   Default behavior:
	       Symbolic links are skipped.

	   --links
	       Allows symbolic links to be processed.

	   Important notes:
	       - A symlink to a file is treated as a file by Bash tests.
	       - A symlink to a directory is treated as a directory by Bash tests.
	       - Recursive symbolic links can create confusing directory trees.
	       - Use --links only when you understand where the links point.

	8. HIDDEN FILES
	   Default behavior:
	       Hidden files are not included by script-side wildcard expansion.

	   --hidden
	       Enables Bash dotglob inside the script.
	       This means recursive expansion such as DIRECTORY/* will include:
	         .hidden-file
	         .hidden-directory

	   Important shell note:
	       If you run: Sort.sh *
	       your interactive shell expands * before Sort.sh starts.
	       In that case, --hidden cannot add hidden top-level files that were never passed.

	   Recommended hidden-file examples:
	       Sort.sh --hidden --recursive ~/Downloads
	       Sort.sh --hidden ~/Downloads/.* ~/Downloads/*

	9. REPLACE AND NAME COLLISIONS
	   Default behavior:
	       Existing target files are not overwritten.
	       The script appends a counter:
	         file.jpg
	         file-(1).jpg
	         file-(2).jpg

	   --replace
	       Allows existing target files to be overwritten.
	       Use this carefully.

	10. TITLE / METADATA NAMING
	   --title
	       Attempts to create names from embedded metadata.

	   Current behavior by MIME main type:
	       application  PDF/document title scan when possible
	       image        camera make/model via ffprobe metadata
	       audio        artist-title via ffprobe metadata
	       video        internal video title via ffprobe metadata
	       other        original filename fallback

	11. ORGANIZATION OPTIONS
	   --dirs=VALUE
	       Builds the first part of the target directory.

	   --subdirs=VALUE
	       Adds a second directory pattern below --dirs.

	   --rename=VALUE
	       Replaces the base filename.

	   --extension=VALUE
	       Replaces the file extension.
	       Slashes are converted to dots, and spaces are converted to underscores.

	12. DYNAMIC VALUES
	   Date values:
	       year              Four-digit year
	       month             Two-digit month
	       day               Two-digit day
	       year+month        YYYY/MM
	       year+month+day    YYYY/MM/DD
	       created           Full creation timestamp from stat
	       modified          Full modification timestamp from stat
	       accessed          Full access timestamp from stat

	   MIME values:
	       mime              Full MIME type, for example IMAGE/JPEG
	       mime-main         Main MIME type, for example IMAGE
	       mime-sub          Sub MIME type, for example JPEG
	       extension         Original file extension

	   Size and format values:
	       size              Media: resolution, for example 1920x1080
	                         Other files: compact byte size, for example 45MB

	       format            Media: size/aspect label, for example BIG/WIDE
	                         Other files: size class, for example Mega

	       size+format       Media: format/resolution-style path
	                         Other files: binary-style value, for example 45_MiB

	       format+size       Media: format/resolution-style path
	                         Other files: class/value path, for example Mega/45

	   Hash/random values:
	       md5
	       sha1sum
	       sha224sum
	       sha256sum
	       sha384sum
	       sha512sum
	       random

	13. PROCESS ORDER
	   For every file, the script roughly does this:
	       1. Read command-line options as they appear.
	       2. Skip missing paths.
	       3. Skip symlinks unless --links is enabled.
	       4. Enter directories only when --recursive is enabled.
	       5. Detect MIME type.
	       6. Apply --type filter.
	       7. Build target directory from --dirs and --subdirs.
	       8. Build filename from --title, original name, or --rename.
	       9. Build extension from original extension or --extension.
	      10. Avoid filename collisions unless --replace is enabled.
	      11. Create target directories.
	      12. Copy, move, remove, or test-print the action.
	      13. Pause if --pause=SEC is set.

	14. EXAMPLES
	   Dry run, show what would happen:
	       Sort.sh *

	   Move images by year/month and image format:
	       Sort.sh --mode=move --type=image --dirs=year+month --subdirs=format ~/Pictures/*

	   Recursively include hidden files:
	       Sort.sh --recursive --hidden --dirs=mime-main ~/Downloads

	   Process symbolic links too:
	       Sort.sh --recursive --links --dirs=mime-main ~/LinkedFolder

	   Rename files to SHA256 hash:
	       Sort.sh --mode=copy --rename=sha256sum *

	   Sort videos by resolution:
	       Sort.sh --mode=move --type=video --dirs=size --subdirs=format ~/Videos/*

	   Create MIME-style extensions:
	       Sort.sh --mode=copy --extension=mime-sub *

	15. NOTES AND LIMITATIONS
	   - The script uses file for MIME detection.
	   - The script uses ffprobe for media metadata where available.
	   - Hidden top-level files must be passed to the script or reached through recursion.
	   - Symbolic links are skipped unless --links is used.
	   - Broken symbolic links may still be reported as missing or unusable.
	   - Recursive symlink traversal can be risky; avoid --links on unknown directory trees.
	   - Birth/creation time depends on filesystem support. Some filesystems return no birth time.
	   - --replace overwrites target files when copy/move commands are executed.
	   - Without --mode, the script is safe and performs no file operations.
	   - The script is verbose by design, so you can see progress, target paths, names, and actions.

	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
	Draw_Line "━"
}


# Version() prints program identity, feature summary, dependency status, and basic system information.
# This is useful when debugging another user's report because it shows the environment immediately.
function Version {
	Draw_Line "="
	cat << EOF
${ICON_VERSION} ${PROGRAM} v${VERSION}
${DESCRIPTION}

Author : ${AUTHOR}
License: ${LICENSE}

Capabilities:
  Copy        Yes
  Move        Yes
  Remove      Yes
  Dry-run     Yes

Features:
  Recursive   Yes
  Hidden      Yes, with --hidden
  Links       Yes, with --links
  Title       Yes, with --title
  MIME        Yes, through file
  Metadata    Yes, through ffprobe/stat
  Hashes      Yes

Hash Algorithms:
  md5
  sha1sum
  sha224sum
  sha256sum
  sha384sum
  sha512sum

Supported Metadata:
  PDF title
  Image camera make/model
  Audio artist/title
  Video title
  MIME main/subtype
  File dates and size
  Media width/height

Dependencies:
EOF
	for Key in "${!Required[@]}"; do
		if command -v "$Key" >/dev/null 2>&1; then
			printf "  %s [OK]   %-12s %s\n" "$ICON_OK" "$Key" "${Required[$Key]}"
		else
			printf "  %s [FAIL] %-12s %s\n" "$ICON_ERROR" "$Key" "${Required[$Key]}"
		fi
	done
	printf "\nShell:\n"
	printf "  Bash    %s\n" "$BASH_VERSION"
	printf "\nSystem:\n"
	printf "  Kernel  %s\n" "$(uname -s 2>/dev/null)"
	printf "  Machine %s\n" "$(uname -m 2>/dev/null)"
	Draw_Line "="
}

# Backward-compatible spelling alias requested earlier.
function Manuel { Manual "$@"; }

# --- CLI Execution ---
# Check if arguments were provided.
if [ $# -gt 0 ]; then
	# Start the sorting process.
	Sort "$@"

	printf "\n$ICON_DONE $GREEN FINISHED:$RESET all operations completed.\n\n"

	IFS=$OIFS # Restore original separator.
else
	# No arguments: show the short usage overview.
	Usage
fi
