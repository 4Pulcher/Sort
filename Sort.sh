#!/bin/bash
# Sort.sh v2.1 - Media-Intelligent File Organizer
# Developed by: Ali_ISIN
# Function: Organizes files based on MIME type, metadata, and user-defined path patterns.

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

# --- 1. Check Requirements ---
# Associative array mapping required binaries to their respective software packages.
declare -A Required=(
	[file]='Linux Base' [stat]='Linux Base' [cp]='Linux Base'
	[mv]='Linux Base' [rm]='Linux Base' [find]='Linux Base'
	[sha256sum]='Linux Base' [ffprobe]='FFMPEG'
)

# Loop through the required commands to ensure they are installed in the system PATH.
for Key in "${!Required[@]}"; do
	if ! command -v "$Key" &> /dev/null; then
		# If a command is missing, notify the user and provide the package name.
		printf "$RED ERROR:$RESET '$Key' command is not installed. Install: ${Required[$Key]}\!\n"
		exit 10
	fi
done

# --- 2. Setup & Safety ---
OIFS=$IFS # Save the Original Internal Field Separator to restore on exit.

# Function to handle clean exit if the user interrupts the script (Ctrl+C).
function Break {
	IFS=$OIFS;
	printf "\nTerminated by user\!\!\n";
	exit 1;
}
trap Break INT       # Traps the SIGINT signal.
shopt -s dotglob     # Ensures that wildcards (*) match hidden files (starting with '.').

# --- Helper Functions ---

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

# Image Metadata: Retrieves Width x Height resolution via ImageMagick's 'identify'.
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
	[[ ! "$1" =~ [0-9]+x[0-9]+ ]] && { printf "0x0"; return; }
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
	local Req="${1,,}" File="$2" Res=""
	case "$Req" in
		"year")           Res=$(Get_Date_Part "$File" "+%Y" "0000") ;;
		"month")          Res=$(Get_Date_Part "$File" "+%m" "00") ;;
		"day")            Res=$(Get_Date_Part "$File" "+%d" "00") ;;
		"year+month")     Res=$(Get_Date_Part "$File" "+%Y/%m" "0000/00") ;;
		"year+month+day") Res=$(Get_Date_Part "$File" "+%Y/%m/%d" "0000/00/00") ;;
		"extension")      local e=$(Get_File_Ext "$File"); Res=${e^^} ;; # Forces extension to uppercase.
		"mime")           Res=${MIME^^} ;;
		"mime-main")      Res=${MIMEMain^^} ;;
		"mime-sub")       Res=${MIMESub^^} ;;
		"size"|"format"|"size+format"|"format+size")
			# Context-aware sizing: Media files get resolution/tier, other files get byte-size labels.
			if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
				local WxH=$([ "$MIMEMain" == "image" ] && Get_Image_WxH "$File" || Get_Video_WxH "$File")
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
		"created") Res=$(Get_File_Creation_Time "$File") ;;
		"modified") Res=$(Get_File_Modification_Time "$File") ;;
		"accessed") Res=$(Get_File_Access_Time "$File") ;;
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
		case "${Item,,}" in
			# Parsing CLI Arguments.
			"--pause="*)     ((Total[$Current]--)); Pause=${Item#*=};;
			"--type="*)      ((Total[$Current]--)); Type=${Item#*=};;
			"--mode="*)      ((Total[$Current]--)); Mode=${Item#*=};;
			"--recursive")   ((Total[$Current]--)); Recursive="yes";;
			"--replace")     ((Total[$Current]--)); Replace="yes";;
			"--rename="*)    ((Total[$Current]--)); Rename=${Item#*=};;
			"--title")       ((Total[$Current]--)); Title="yes";;
			"--extension="*) ((Total[$Current]--)); Extension=${Item#*=};;
			"--dirs="*)      ((Total[$Current]--)); Dirs=${Item#*=};;
			"--subdirs="*)   ((Total[$Current]--)); SubDirs=${Item#*=};;
			*)
			# Incremental progress tracking output for the UI.
			((Counter[$Current]++))
			printf "PROGRESS"
			for (( i=1; i<=$Current; i++ )); do printf " ~ [$i]=${Counter[$i]}/${Total[$i]}"; done; printf "\n"

			# Basic sanity checks (existence, symlink detection).
			if [[ ! -e "$Item" ]]; then printf "SKIP: Missing $Item\n"
			elif [[ -L "$Item" ]]; then printf "SKIP: Symlink $Item\n"
			elif [[ -d "$Item" ]]; then
				# If the current item is a Directory.
				Draw_Line "="
				if [ "$Recursive" = "yes" ]; then
					printf "$BOLDBLUE DIR:$YELLOW $Item$RESET\n"
					Draw_Line ">"
					Sort "$Item"/* # RECURSIVE STEP: Enter directory and call Sort again.
					# After returning from a recursive move, try to cleanup the now-empty source folder.
					if [ "$Mode" = "move" ]; then
						local CleanupLog
						local RMDir=${Item%\*}
						CleanupLog=$(rmdir -v "$RMDir" 2>&1)

						if [ $? -eq 0 ]; then
							printf "$BLUE CLEANUP:$RESET %s\n" "$CleanupLog"
						else
							# If folder isn't empty (due to filtered files), ignore but log the event.
							printf "$RED ERROR:$RESET Directory not empty, skipping cleanup: $Item\n"
						fi
					fi
				else
					printf "$RED DIR:$RESET Skipping!\n"
				fi
				Draw_Line "="
			elif [[ -f "$Item" ]]; then
				# If the current item is a File.
				Draw_Line "-"
				printf "$BOLDGREEN FILE:$YELLOW $Item$RESET\n"

				# Pre-calculate MIME and sub-MIME types.
				MIME=$(Get_MIME "$Item")
				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}
				printf "$YELLOW MIME:$RESET $MIME\n"

				# Filter check: Process only if no type filter is set, or if the file MIME matches.
				if [ -z "$Type" ] || [[ "${MIME^^}" == *"${Type^^}"* ]]; then

					# Step 1: Construct the Target Path using user-defined patterns.
					D=$(Resolve_Path_Segment "$Dirs" "$Item")
					SD=$([ -n "$SubDirs" ] && Resolve_Path_Segment "$SubDirs" "$Item" || printf "")

					Loc="."
					[ -n "$D" ] && Loc="${D^^}"
					[ -n "$SD" ] && Loc="$Loc/${SD^^}"

					printf "$YELLOW TARGET:$RESET $Loc\n"

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

					# Override name if a specific --rename pattern was provided.
					[ -n "$Rename" ] && Name=$(Resolve_Path_Segment "$Rename" "$Item")

					# Handle extension renaming or default extension extraction.
					Ext=$(Get_File_Ext "$Item")
					if [ -n "$Extension" ]; then
						Ext=$(Resolve_Path_Segment "$Extension" "$Item")
						Ext=${Ext,,} # Normalize extension to lowercase.
						Ext=${Ext//\//.} # Safety: replace slashes with dots.
						Ext=${Ext// /_}  # Safety: replace spaces with underscores.
					fi

					# Step 3: Collision Management.
					NewName="$Name.$Ext"
					# If not in 'replace' mode, find a unique name (e.g. file-(1).jpg) if target exists.
					if [ -z "$Replace" ] || [ -z "$Title" ]; then
						C=0
						BaseName="$Name"
						while [ -e "$Loc/$NewName" ]; do
							((C++))
							NewName="$BaseName-($C).$Ext"
						done
					fi

					printf "$YELLOW NEW-NAME:$RESET $NewName\n"

					# Step 4: Perform the Action (Move, Copy, or Trash).
					if [ -n "$Mode" ]; then
						# Ensure target directory structure exists.
						printf "$YELLOW MKDIR:$RESET %s\n" "$(mkdir -v -p "$Loc")"

						case "$Mode" in
							"move")   printf "$RED MOVE:$RESET %s\n"   "$(mv -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
							"copy")   printf "$RED COPY:$RESET %s\n"   "$(cp -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
							"remove") printf "$RED REMOVE:$RESET %s\n" "$(trash-put -v "$Item" 2>&1)" ;;
						esac
					else
						# Dry Run Mode: Show user what would happen without making changes.
						printf "$GREEN TEST:$RESET $Item -> $Loc/$NewName\n"
					fi

					# Optional pause to slow down execution for visual monitoring.
					[ -n "$Pause" ] && sleep "$Pause"

					Draw_Line "-"
				fi
			fi ;;
		esac
	done
	((Current--)) # Level finished, pop back up to the parent directory level.
}

# --- CLI Execution ---
# Check if arguments were provided.
if [ $# -gt 0 ]; then
	# Start the sorting process.
	Sort "$@"

	printf "\n$GREEN---DONE---$RESET\n\n"

	IFS=$OIFS # Restore original separator.
else
	# No arguments: Display the Help/Usage menu.
	Draw_Line "━"
	cat << EOF
	📂	Sort.sh v2.1 | Media-Intelligent File Organizer
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
							Developed by: Ali_ISIN

	SYNTAX:
		Sort.sh [OPTIONS] [FILE/DIR LIST]

	OPERATIONAL MODES: (Choose one)
	--mode=copy       Duplicates files to the new destination.
	--mode=move       Relocates files (deletes source after success).
	--mode=remove     Deletes the target files permanently (moves to trash).

	FILTERS & BEHAVIOR:
	--type=VALUE      Filter by MIME (e.g., 'image', 'video', 'pdf').
	--recursive       Process subdirectories found in the list.
	--replace         Overwrite existing files (Be careful!).
	--title Behavior by File Type:
		VIDEO:   Extracts internal 'Title' tag.
		AUDIO:   Extracts 'Artist - Title' tags.
		IMAGE:   Extracts Camera Make & Model.
		PDF:     Extracts internal Document Title.
		OTHER:   Falls back to SHA256 content hash.
	--pause=SEC       Wait X seconds between each file action.

	ORGANIZATION SETTINGS:
	--dirs=OPT        Primary directory structure.
	--subdirs=OPT     Secondary directory structure.
	--rename=OPT      Override filename with a dynamic value.
	--extension=OPT   Override file extension with a dynamic value.

	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	DYNAMIC OPTION VALUES (Used for --dirs, --subdirs, --rename):

	DATE & TIME:
		year, month, day  Standard date parts (YYYY, MM, DD).
		year+month        Folder structure: YYYY/MM.
		year+month+day    Folder structure: YYYY/MM/DD.
		created           Full creation timestamp (if supported).
		modified          Full modification timestamp.
		accessed          Last access timestamp.

	MIME & IDENTITY:
		extension         File extension (UPPERCASE for folders).
		mime-main         MIME Category (IMAGE, VIDEO, APPLICATION).
		mime-sub          MIME Subtype (PNG, MP4, PDF).
		sha256sum         Unique 64-character hash of file content.
		random            Randomized numeric string.

	SMART SIZE (Context Aware):
		size              Media: Resolution (1920x1080) | Files: Size (45MB).
		format            Media: Tier (BIG/WIDE)        | Files: Label (MegaByte).

	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	EXAMPLES:

	# Organize videos by Title and put them in folders by Category:
	Sort.sh --mode=move --dirs=mime-main --title ./Downloads/*

	# Rename all images to their SHA256 hash and sort by year:
	Sort.sh --mode=copy --dirs=year --rename=sha256sum *.jpg

	# Detailed sorting of documents by size labels:
	Sort.sh --mode=move --dirs=extension --subdirs=format+size *.pdf
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
	Draw_Line "━"
fi
