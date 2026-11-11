#!/bin/bash
# Sort.sh v2.2 - Media-Intelligent File Organizer
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
# External commands used by the script.
# "Required" lists commands needed by the current implementation. Optional
# commands are listed separately because they are only needed for certain
# features or modes.
declare -A Required=(
	[file]="file (usually the file package)"
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
	[ffprobe]="FFmpeg"
	[identify]="ImageMagick"
	[tput]="ncurses / terminfo"
	[cat]="coreutils"
)

# Optional external commands:
# - trash-put: required only for --mode=trash / --trash.
# - shred: required only for --mode=shred.
# - sha1sum, sha224sum, sha384sum, sha512sum, shasum, sha1deep,
#   sha256deep: required only when the corresponding hash keyword is used.
# The hash commands are invoked from /usr/bin by Get_SHA_Keys.

# Loop through the required commands to ensure they are installed in the system PATH.
Errors=0
for Key in "${!Required[@]}"; do
	if ! command -v "$Key" &> /dev/null; then
		# If a command is missing, notify the user and provide the package name.
		printf "${RED}ERROR:${RESET} '$Key' command IS NOT installed. Install package: ${Required[$Key]}\!\n"
		((Errors++))
	else
		printf "${GREEN}OK:${RESET} '$Key' command IS installed. Package: ${Required[$Key]}\!\n"
	fi
done

[ $Errors -gt 0 ] && { printf "ERROR: Missing ($Errors) found!\n"; exit $Errors; }

# --- 2. Setup & Safety ---

OIFS=$IFS # Save the Original Internal Field Separator to restore on exit.

# Function to handle clean exit if the user interrupts the script (Ctrl+C).
function Exit {
	echo "Waiting for jobs to end..."
	wait
	IFS=$OIFS;
	echo "Finished\!"
	trap - EXIT              # Disable the EXIT trap before calling exit.
	exit "$1"
}

function Break {
	printf "\nTerminated by user\!\!\n";
	Exit -1;
}

trap Break INT       # Traps the SIGINT signal.
trap Exit EXIT         # Run cleanup when the script exits.
shopt -s dotglob     # Ensures that wildcards (*) match hidden files (starting with '.').

# --- Helper Functions ---

function Get_MD5Sum {
	local Sum=$(md5sum -b "$1" | cut -d' ' -f1)
	printf "%s" "${Sum:-ERROR}"
}

function Get_SHA_Keys {
	# Execute the system hashing tool matching the keyword.
	local Sum=$(/usr/bin/$1 -b "$2" | cut -d' ' -f1)
	printf "%s" "${Sum:-ERROR}"
}

# Generates a SHA256 hash of the file content for unique identification.
function Get_SHA256Sum {
	local Sum=$(sha256sum -b "$1" | cut -d' ' -f1)
	printf "%s" "${Sum:-ERROR}"
}

# Detects the MIME type (e.g., image/jpeg) using the 'file' utility.
function Get_MIME {
	local MIME=$(file -b --mime-type "$1" 2>/dev/null)
	printf "%s" "${MIME:-ERROR}"
}

# Extracts the filename without the path and without the last extension.
function Get_File_Name {
	local name="${1##*/}"
	printf "%s" "${name%.*}"
}

# Extracts just the file extension (everything after the last dot).
function Get_File_Ext  { printf "%s" "${1##*.}"; }

# Gets the file size in bytes using 'stat'. Defaults to 0 if the file is inaccessible.
function Get_File_Size {
	local size=$(stat -c %s "$1" 2>/dev/null)
	printf "%d" "${size:-0}"
}

# Gets the file birth (creation) time as a Unix timestamp.
function Get_File_Birth {
	local Time=$(stat -c %W "$1" 2>/dev/null)
	printf "%s" "${Time:-0}"
}

# Detailed 'stat' functions for various timestamps (Creation, Access, Modification).
function Get_File_Creation_Time {
	local Time=$(stat -c %w "$1" 2>/dev/null)
	printf "%s" "${Time:-0}"
}

function Get_File_Access_Time {
	local Time=$(stat -c %x "$1" 2>/dev/null)
	printf "%s" "${Time:-0}"
}

function Get_File_Modification_Time {
	local Time=$(stat -c %y "$1" 2>/dev/null)
	printf "%s" "${Time:-0}"
}

# Converts a birth timestamp into a specific date part (Year, Month, etc.) using 'date'.
function Get_Date_Part {
	local Time=$(Get_File_Birth "$1")
	[ "$Time" != "0" ] && {
		printf "%s" "$(date -d "@$Time" "$2" 2>/dev/null)"
	} || printf "$3"
}

# Image Metadata: Retrieves Width x Height resolution via ImageMagick's 'identify'.
function Get_Image_WxH {
	local resolution
	
	resolution=$(identify -ping -format '%wx%h\n' "$1" 2>/dev/null | head -n 1 | tr -d '\r\n ')
	
	resolution=${resolution%x}
	
	printf "%s" "${resolution:-0x0}"
}

# Video Metadata: Retrieves resolution via FFmpeg's 'ffprobe'.
function Get_Media_WxH {
	local resolution=$(
		timeout 10s \
		ffprobe -v error \
		-select_streams v:0 \
		-show_entries stream=width,height \
		-of csv=s=x:p=0 \
		"$1" 2>/dev/null
	)
	resolution=${resolution%x}
	
	printf "${resolution:-0x0}"
}

# Logic to categorize resolutions into human-readable tiers (SMALL, MEDIUM, BIG) and aspect ratios.
function Get_WxH_Format {
	local input="$1"
	if [[ "$input" =~ ^[0-9]+x[0-9]+$ ]]; then
		if [ "$input" == "0x0" ]; then
			printf "ZERO"
			return
		fi
		
		local W=${input%%x*} H=${input##*x}
		local MAX=$W
		[ "$H" -gt "$W" ] && MAX=$H
		
		local L="TINY"
		[ "$MAX" -gt 32 ] && L="MINI"
		[ "$MAX" -gt 512 ] && L="SMALLER"
		[ "$MAX" -gt 1024 ] && L="SMALL"
		[ "$MAX" -gt 2048 ] && L="MEDIUM"
		[ "$MAX" -gt 4096 ] && L="BIG"
		[ "$MAX" -gt 8192 ] && L="BIGGER"
		[ "$MAX" -gt 16384 ] && L="HUGE"
		
		local A="SQUARE"
		[ "$W" -gt "$H" ] && A="WIDE"
		[ "$W" -lt "$H" ] && A="HIGH"
		
		printf "%s/%s" "$L" "$A"
	else
		printf "ERROR"
	fi
}

# PDF Document Helper: Scans internal PDF stream for the '/Title' tag using grep.
function Get_Doc_Title {
	local Title=$(grep -a "/Title" "$1" | head -n 1 | sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_')
	
	[ -z "$Title" ] && Title=$(Get_File_Name "$1")
	
	printf "${Title:-ERROR}"
}

# Image Metadata Helper: Extracts Camera Make and Model tags.
function Get_Image_Meta {
	local Date=$(
		timeout 5s \
		ffprobe -v error \
		-show_entries format_tags=date_time_original \
		-of default=noprint_wrappers=1:nokey=1 \
		"$1" 2>/dev/null
	)
	
	[ -z "$Date" ] && Date=$(Get_File_Creation_Time "$1")
	
	printf "${Date:-ERROR}"
}

# Audio Metadata Helper: Extracts Artist and Title tags using ffprobe.
function Get_Audio_Info {
	local Artist=$(
		timeout 10s \
		ffprobe -v error \
		-show_entries format_tags=artist \
		-of default=noprint_wrappers=1:nokey=1 \
		"$1" 2>/dev/null
	)
	
	local Album=$(
		timeout 10s \
		ffprobe -v error \
		-show_entries format_tags=album \
		-of default=noprint_wrappers=1:nokey=1 \
		"$1" 2>/dev/null
	)
	
	local Title=$(
		timeout 5s \
		ffprobe -v error \
		-show_entries format_tags=title \
		-of default=noprint_wrappers=1:nokey=1 \
		"$1" 2>/dev/null
	)
	
	local Info
	[ -n "$Artist" ] && Info="$Artist"
	[ -n "$Album" ] && Info="${Info:+$Info - }$Album"
	[ -n "$Title" ] && Info="${Info:+$Info - }$Title"
	
	# Clean title: Remove characters that are illegal in filenames.
	printf "$Info" | tr -d '/\\:*?"<>|'
}

# Video Metadata Helper: Extracts internal 'artist' and 'title' tag from video containers.
function Get_Video_Title {
	local Title=$(
		timeout 10s \
		ffprobe -v error \
		-show_entries format_tags=title \
		-of default=noprint_wrappers=1:nokey=1 \
		"$1" 2>/dev/null
	)
	
	local Artist=$(
		timeout 10s \
		ffprobe -v error \
		-show_entries format_tags=artist \
		-of default=noprint_wrappers=1:nokey=1 \
		"$1" 2>/dev/null
	)
	
	local Info
	[ -n "$Artist" ] && Info="$Artist"
	[ -n "$Title" ] && Info="${Info:+$Info - }$Title"
	
	printf "$Info" | tr -d '/\\:*?"<>|'
}

# Master Path Resolver: Converts dynamic keywords (like 'year' or 'size') into actual file attributes.
function Resolve_Path_Segment {
	local Req="${1,,}" File="$2"
	case "$Req" in
		"year")           Get_Date_Part "$File" "+%Y" "0000" ;;
		"month")          Get_Date_Part "$File" "+%m" "00" ;;
		"day")            Get_Date_Part "$File" "+%d" "00" ;;
		"year+month")     Get_Date_Part "$File" "+%Y/%m" "0000/00" ;;
		"year+month+day") Get_Date_Part "$File" "+%Y/%m/%d" "0000/00/00" ;;
		
		"extension")      Get_File_Ext "$File" ;;
		
		"mime")           printf "${MIME^^}" ;;
		"mime-main")      printf "${MIMEMain^^}" ;;
		"mime-sub")       printf "${MIMESub^^}" ;;
		
		"size"|"format"|"size+format"|"format+size")
			# Context-aware sizing: Media files get resolution/tier, other files get byte-size labels.
			[[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]] && {
				local Size=$([ "$MIMEMain" == "image" ] && Get_Image_WxH "$File" || Get_Media_WxH "$File")
				local Format=$(Get_WxH_Format "$Size")
				
				if [ "$Format" == "ZERO" ]; then
					printf "ZERO"
				else
					[[ "$Req" == "size" ]] && printf "$Size" || {
						[[ "$Req" == "format" ]] && printf "$Format" || printf "$Format/$Size"
					}
				fi
			} || {
				# General file size formatting (B, KB, MB, etc.)
				local S=$(Get_File_Size "$File")
				local T=$S N=0 Div=1000
				local U=("B" "KB" "MB" "GB" "TB" "PB")

				if [[ "$Req" == "size+format" ]] ; then
					Div=1024
					U=("B" "KiB" "MiB" "GiB" "TiB")
				elif [[ "$Req" == "format"* ]] ; then
					Div=1000
					U=("Byte" "Kilo" "Mega" "Giga" "Tera")
				fi

				while [ "$T" -gt "$((Div-1))" ] && [ "$N" -lt "5" ]; do ((N++)); T=$((T/Div)); done

				case "$Req" in
					"size") printf "$T${U[$N]}" ;;
					"size+format") printf "${T}_${U[$N]}" ;;
					"format") printf "${U[$N]}" ;;
					"format+size") printf "${U[$N]}/$T" ;;
				esac
			} ;;
		
		"created")
			Get_File_Creation_Time "$File" ;;
			
		"modified")
			Get_File_Modification_Time "$File" ;;
			
		"accessed")
			Get_File_Access_Time "$File" ;;
		
		"md5"|"md5sum")
			Get_MD5Sum "$File" ;;
		
		"sha"|"sha1"|"sha224"|"sha256"|"sha384"|"sha512")
			Get_SHA_Keys "${Req}sum" "$File" ;;
		
		"shasum"|"sha1deep"|"sha1sum"|"sha224sum"|"sha256deep"|"sha256sum"|"sha384sum"|"sha512sum")
			Get_SHA_Keys "$Req" "$File" ;;
		
		"random"*)
			local Count=${Req#random}
			
			[ -z "$Count" ] && {
				printf "$RANDOM"
			} || {
				while [ "$Count" -gt 0 ]
				do
					printf "$RANDOM"
					((Count--))
				done
			}
		;;
	esac
}

# UI Tool: Creates a horizontal rule based on the current terminal width.
function Draw_Line {
	local Width=$(tput cols 2>/dev/null)
	local Symbol=${1:-=}
	
	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
}

# --- Main Logic ---

# Global arrays to track progress across multiple recursion levels.
declare -a Total Counter
Current=0
MAX_JOBS=4

# The core recursive function that handles the actual sorting of files and directories.
function Sort {
	((Current++))
	Total[$Current]=$#      # Track how many items were passed to the current call.
	Counter[$Current]=0     # Initialize current progress to zero.
	
	local Item
	for Item in "$@"; do
		case "${Item,,}" in
			# Parsing CLI Arguments.
			"--copy"|"--move"|"--delete"|"--remove"|"--trash")
				((Total[$Current]--)); Mode=${Item#'--'} ;;
			
			"--mode="*)      ((Total[$Current]--)); Mode=${Item#*=} ;;
			
			"--jobs="*)      ((Total[$Current]--)); MAX_JOBS=${Item#*=} ;;
			
			"--type="*)      ((Total[$Current]--)); Type=${Item#*=} ;;
			
			"--recursive")   ((Total[$Current]--)); Recursive="yes" ;;
			
			"--dirs="*)      ((Total[$Current]--)); Dirs=${Item#*=} ;;
			
			"--subdirs="*)   ((Total[$Current]--)); SubDirs=${Item#*=} ;;
			
			"--rename="*)    ((Total[$Current]--)); Rename=${Item#*=} ;;
			
			"--title")       ((Total[$Current]--)); Title="yes" ;;
			
			"--extension="*) ((Total[$Current]--)); Extension=${Item#*=} ;;
			
			"--compare")     ((Total[$Current]--)); Compare="yes" ;;
			
			"--replace")     ((Total[$Current]--)); Replace="yes" ;;
			
			"--pause="*)     ((Total[$Current]--)); Pause=${Item#*=} ;;
			
			*)
				# Incremental progress tracking output for the UI.
				((Counter[$Current]++))
				printf "PROGRESS"
				for (( i=1; i<=$Current; i++ )); do printf " ~ [$i]=${Counter[$i]}/${Total[$i]}"; done; printf "\n"

				# Basic sanity checks (existence, symlink detection).
				[[ -e "$Item" ]] && {
					[[ -L "$Item" ]] && {
						printf "SKIP: Symlink $Item\n"
					} || {
						[[ -d "$Item" ]] && {
							# If the current item is a Directory.
							Draw_Line "="
							[ "$Recursive" = "yes" ] && {
								printf "${BLUE}DIR:${YELLOW} $Item${RESET}\n"
								Draw_Line ">"
								
								# RECURSIVE STEP: Enter directory and call Sort again.
								Sort "$Item"/*
								
								Draw_Line "<"
								# After returning from a recursive move, try to cleanup the now-empty source folder.
								[ "$Mode" = "move" ] && printf "${RED}DIR:${YELLOW}_Remove:${RESET} %s\n" "$(rmdir -v "$Item")"
							} || {
								printf "${RED}DIR:${YELLOW}_Skipping: Recursive not set\!${RESET}\n"
							}
							Draw_Line "="
						} || {
							[[ -f "$Item" ]] && {
							# (
								# If the current item is a File.
								Draw_Line "-"
								printf "${GREEN}FILE:${YELLOW} $Item${RESET}\n"
								
								# Pre-calculate MIME and sub-MIME types.
								MIME=$(Get_MIME "$Item")
								MIMEMain=${MIME%/*}
								MIMESub=${MIME#*/}
								
								printf "${YELLOW}MIME:${RESET} $MIME\n"

								# Filter check: Process only if no type filter is set, or if the file MIME matches.
								if [ -z "$Type" ] || [[ "${MIME^^}" == *"${Type^^}"* ]]; then
									# Step 1: Construct the Target Path using user-defined patterns.
									local D SD Name Ext NewName
									D=$([ -n "$Dirs" ] && Resolve_Path_Segment "$Dirs" "$Item" || printf "${Item%/*}")
									
									SD=$([ -n "$SubDirs" ] && Resolve_Path_Segment "$SubDirs" "$Item" || printf "")

									local Loc="."
									[ -n "$D" ] && Loc="$D"
									[ -n "$SD" ] && Loc="$Loc/$SD"

									printf "${YELLOW}TARGET:${RESET} $Loc\n"

									# Step 2: Build the Target Filename.
									
									# Override name if a specific --rename pattern was provided.
									[ -n "$Rename" ] && Name=$(Resolve_Path_Segment "$Rename" "$Item")
									
									# When --title flag is set, attempt to pull metadata based on the file type.
									[ -n "$Title" ] && {
										local Tmp
										
										case "${MIMEMain,,}" in
										"application") Tmp=$(Get_Doc_Title "$Item") ;;
										"image")       Tmp=$(Get_Image_Meta "$Item") ;;
										"audio")       Tmp=$(Get_Audio_Info "$Item") ;;
										"video")       Tmp=$(Get_Video_Title "$Item") ;;
										esac
										
										[ -n "$Tmp" ] && Name=$Tmp
									}

									# Fallback to the original filename if no title was extracted or requested.
									[ -z "$Name" ] && Name=$(Get_File_Name "$Item")

									# Handle extension renaming or default extension extraction.
									[ -z "$Extension" ] && Ext=$(Get_File_Ext "$Item") || {
										[ -n "$Extension" ] && Ext=$(Resolve_Path_Segment "$Extension" "$Item")
									}
									Ext=${Ext,,}
									Ext=${Ext/\//.}

									# Step 3: Collision Management.
									NewName="$Name.$Ext"

									# If not in 'replace' mode, find a unique name (e.g. file-(1).jpg) if target exists.
									if [[ "$Mode" = "copy" || "$Mode" = "move" ]] && [ -z "$Replace" ]; then
										local C=0
										BaseName="$Name"
										while [ -e "$Loc/$NewName" ]; do
											((C++))
											NewName="$BaseName-($C).$Ext"
										done
									fi
									
									printf "${YELLOW}NEW-NAME:${RESET} $NewName\n"
									
									# Step 4: Perform the Action (Move, Copy, or Trash).
									[ -n "$Mode" ] && {
										# Ensure target directory structure exists.
										[[ "$Mode" = "copy" || "$Mode" = "move" ]] && printf "${YELLOW}MK-DIR:${RESET} %s\n" "$(mkdir -v -p "$Loc")"
										
										case "$Mode" in
											## Needs cmp!
											"copy")   printf "${RED}COPY:${RESET} %s\n"   "$(cp -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
											"move")   printf "${RED}MOVE:${RESET} %s\n"   "$(mv -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
											"delete"|"remove") printf "${RED}REMOVE:${RESET} %s\n" "$([ -e "$Loc/$NewName" ] && { [[ "$(realpath "$Item")" == "$(realpath "$Loc/$NewName")" ]] && printf "ERROR: The files are the same ($(realpath "$Item"))" || rm -v -f "$Loc/$NewName" 2>&1; } || echo "File not found!")" ;;
											"trash") printf "${RED}DELETE:${RESET} %s\n" "$([ -e "$Loc/$NewName" ] && { [[ "$(realpath "$Item")" == "$(realpath "$Loc/$NewName")" ]] && printf "ERROR: The files are the same ($(realpath "$Item"))" || trash-put -v -f "$Loc/$NewName" 2>&1; } || echo "File not found!")" ;;
											"shred") printf "${RED}REMOVE:${RESET} %s\n" "$([ -e "$Loc/$NewName" ] && { [[ "$(realpath "$Item")" == "$(realpath "$Loc/$NewName")" ]] && printf "ERROR: The files are the same ($(realpath "$Item"))" || shred -u -n 1 -- "$Loc/$NewName" 2>&1; } || echo "File not found!")" ;;
										esac
									} || {
										# Dry Run Mode: Show user what would happen without making changes.
										printf "${BLUE}TEST:${RESET} $Item -> $Loc/$NewName\n"
									}
									
									# Optional pause to slow down execution for visual monitoring.
									[ -n "$Pause" ] && sleep "$Pause"
								else
									printf "${YELLOW}TEST: Skipping: MIME does not match\!${RESET}\n"
								fi
								
								Draw_Line "-"
							# ) &
							# Threads... wait!
							# while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.25 ; done
							} || {
								printf "${RED}ERROR: File type unknown: skipping\!${RESET}\n"
							}
						}
					}
				} || { printf "SKIP: Does not exists: $Item\n"; }
				;;
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

	Exit 0
else
	# No arguments: Display the Help/Usage menu.
	Draw_Line "━"
	cat << 'EOF'
Sort.sh v2.1 - Media-Intelligent File Organizer
Organizes files using MIME information, file metadata and dynamic path patterns.

USAGE
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

  Supply one or more files/directories. Quote paths containing spaces.
  With no action mode, Sort.sh performs a dry run and only prints its plan.

OPERATION MODES
  --mode=copy       Copy each processed file to its destination.
  --mode=move       Move each processed file to its destination.
  --mode=delete     Permanently remove the calculated destination file.
  --mode=remove     Alias for delete; permanently remove the destination file.
  --mode=trash      Send the calculated destination file to the desktop trash
                    using trash-put \(requires the trash-cli package).
  --mode=shred      Securely overwrite and unlink the calculated destination
                    using shred \(availability and effectiveness depend on the
                    filesystem and storage device).

  Short forms:
  --copy            Same as --mode=copy.
  --move            Same as --mode=move.
  --delete          Same as --mode=delete.
  --remove          Same as --mode=remove.
  --trash           Same as --mode=trash.

  IMPORTANT: delete/remove/trash/shred operate on the calculated TARGET path,
  not automatically on the original source path. Review the TARGET and
  NEW-NAME output carefully before enabling a destructive mode.

FILTERING AND PROCESSING
  --type=VALUE      Process only files whose MIME string contains VALUE.
                    Examples: --type=image, --type=video, --type=pdf,
                    --type=audio, --type=application.
  --recursive       Recurse into directories supplied as arguments.
  --pause=SECONDS   Sleep for the specified number of seconds after each
                    processed file. The value is passed to sleep.

DESTINATION AND NAMING
  --dirs=VALUE      Choose the primary destination directory component.
  --subdirs=VALUE   Choose an additional component below the primary one.
  --rename=VALUE    Generate the output filename \(without its extension\)
                    from VALUE.
  --extension=VALUE Generate the output extension from VALUE.
  --title           Try to derive the filename from embedded metadata:
                    * application: attempts to read a PDF /Title field
                    * image: reads date_time_original, then falls back to
                      the filesystem creation-time string
                    * audio: combines available Artist, Album and Title tags
                    * video: combines available Artist and Title tags
                    * other MIME types: use the original filename
                    Metadata extraction is best-effort; unsupported or absent
                    tags may result in a fallback filename.

COLLISION HANDLING
  --replace         Allow copy/move to overwrite an existing destination.
                    Without this option, copy/move chooses a suffix such as
                    name-\(1\).ext to avoid an existing destination name.

DYNAMIC VALUES
  These values can be used with --dirs, --subdirs, --rename and --extension.
  Matching is case-insensitive.

  DATE AND FILE TIMES
    year              Birth-time year \(YYYY\); 0000 if unavailable.
    month             Birth-time month \(MM\); 00 if unavailable.
    day               Birth-time day \(DD\); 00 if unavailable.
    year+month        Year/month path \(YYYY/MM\).
    year+month+day    Year/month/day path \(YYYY/MM/DD\).
    created           Filesystem creation-time string \(stat %w\).
    modified          Last modification-time string \(stat \%y\).
    accessed          Last access-time string \(stat \%x\).

  FILE IDENTITY
    extension         Original extension \(text after the final dot\).
    mime              Full MIME type, e.g. IMAGE/JPEG.
    mime-main         MIME major type, e.g. IMAGE or VIDEO.
    mime-sub          MIME subtype, e.g. JPEG, MP4 or PDF.
    md5 / md5sum      MD5 content checksum.
    sha               SHA-1 checksum via shasum.
    sha1              SHA-1 checksum via sha1sum.
    sha224            SHA-224 checksum via sha224sum.
    sha256            SHA-256 checksum via sha256sum.
    sha384            SHA-384 checksum via sha384sum.
    sha512            SHA-512 checksum via sha512sum.
    shasum            Checksum via shasum.
    sha1deep          Checksum via sha1deep.
    sha256deep        Checksum via sha256deep.
    sha1sum           Checksum via sha1sum.
    sha224sum         Checksum via sha224sum.
    sha256sum         Checksum via sha256sum.
    sha384sum         Checksum via sha384sum.
    sha512sum         Checksum via sha512sum.
    random            Bash-generated random number.
    randomN           N concatenated Bash random-number values, e.g. random3.

  SIZE AND MEDIA DIMENSIONS
    size              Images/videos: width x height \(e.g. 1920x1080\).
                      Other files: size expressed using decimal units
                      \(B, KB, MB, GB, TB or PB\).
    format            Images/videos: resolution tier and orientation, e.g.
                      BIG/WIDE. Other files: decimal size-unit name
                      \(Byte, Kilo, Mega, Giga or Tera\).
    size+format       Images/videos: tier/orientation plus dimensions.
                      Other files: size using binary units \(B, KiB, MiB,
                      GiB or TiB\), with an underscore before the unit.
    format+size       Images/videos: tier/orientation plus dimensions.
                      Other files: decimal unit name followed by the size.

  Resolution tiers are based on the larger image/video dimension:
    TINY, MINI, SMALLER, SMALL, MEDIUM, BIG, BIGGER, HUGE.
  Orientation is SQUARE, WIDE or HIGH. If dimensions cannot be read,
  the result is ZERO/ZERO-like fallback \(0x0\) or ZERO.

EXAMPLES
  Preview how image files would be organized by MIME category:
    Sort.sh --dirs=mime-main --type=image ./Downloads/*

  Move video files into year/month folders and use embedded titles:
    Sort.sh --mode=move --dirs=year+month --title --type=video ./Videos/*

  Copy JPEG files and rename them using their SHA-256 checksum:
    Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg

  Organize PDF files by extension and decimal size-unit name:
    Sort.sh --mode=move --dirs=extension --subdirs=format *.pdf

  Preview a destination filename based on the original extension:
    Sort.sh --dirs=mime-main --rename=extension ./Downloads/*

DEPENDENCIES
  Core utilities: file, stat, cp, mv, rm, mkdir, rmdir, realpath, sha256sum,
  md5sum, cut, head, tr, date, timeout, sleep, cat, grep, sed and tput.
  Media metadata: ffprobe \(FFmpeg\) and identify \(ImageMagick\).
  Optional: trash-put for trash mode; shred for shred mode; additional hash
  utilities for the corresponding optional checksum keywords.

NOTES AND LIMITATIONS
  * This script requires Bash \(including associative arrays and [[ ... ]]\).
  * --recursive traverses directories passed as arguments; it is not a
    general-purpose recursive find operation.
  * --jobs and --compare are accepted by the argument parser but are not
    implemented in this version.
  * --title metadata support is best-effort and depends on the file format
    and installed tools.
  * File birth/creation times are filesystem-dependent and may be unavailable.
  * Secure deletion with shred cannot be guaranteed on SSDs, copy-on-write
    filesystems, snapshots, journals or other storage layers.
  * Always test with a dry run \(no --mode option\) before using move/delete,
    trash or shred operations.
EOF
	Draw_Line "━"
	
	Exit -1
fi
