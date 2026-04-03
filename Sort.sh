#!/bin/bash
# by Ali_ISIN - Optimized v2.1

# --- Colors ---

BOLD='\e[1m'

BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'

BOLDBLUE='\e[34m'
BOLDGREEN='\e[32m'
BOLDRED='\e[31m'
BOLDYELLOW='\e[33m'

RESET='\e[0m'

# 1. Check Requirements
declare -A Required=(
	[file]='Linux Base' [stat]='Linux Base' [cp]='Linux Base'
	[mv]='Linux Base' [rm]='Linux Base' [find]='Linux Base'
	[sha256sum]='Linux Base' [ffprobe]='FFMPEG' [identify]='ImageMagick'
)

for Key in "${!Required[@]}"; do
	if ! command -v "$Key" &> /dev/null; then
		printf "$RED ERROR:$RESET '$Key' command is not installed. Install: ${Required[$Key]}\!\n"
		exit 10
	fi
done

# 2. Setup & Safety
OIFS=$IFS
function Break { IFS=$OIFS; printf "\nTerminated by user\!\!\n"; exit 1; }
trap Break INT
shopt -s dotglob

# --- Helper Functions ---

function Get_SHA256Sum { printf "%s" "$(sha256sum -b "$1" | cut -d' ' -f1)"; }

function Get_MIME      { printf "%s" "$(file -b --mime-type "$1" 2>/dev/null)"; }

function Get_File_Name {
	local b=$(basename "$1")
	printf "%s" "${b%.*}"
}

function Get_File_Ext  { printf "%s" "${1##*.}"; }

function Get_File_Size {
	local S=$(stat -c %s "$1" 2>/dev/null)
	printf "%d" "${S:-0}"
}

function Get_File_Birth {
	local B=$(stat -c %W "$1" 2>/dev/null)
	printf "%s" "${B:-0}"
}

function Get_File_Creation_Time {
    printf "%s" "$(stat -c %w "$1" 2>/dev/null)"
}

function Get_File_Access_Time {
    printf "%s" "$(stat -c %x "$1" 2>/dev/null)"
}

function Get_File_Modification_Time {
    printf "%s" "$(stat -c %y "$1" 2>/dev/null)"
}

# Date Helpers
function Get_Date_Part {
	local T=$(Get_File_Birth "$1")
	[ "$T" != "0" ] && date -d "@$T" "$2" 2>/dev/null || printf "$3"
}

# Media Helpers
function Get_Image_WxH {
	local res=$(timeout 10s identify -format "%wx%h" "$1" 2>/dev/null)
	printf "${res:-0x0}"
}

function Get_Video_WxH {
	local res=$(timeout 10s ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null)
	printf "${res:-0x0}"
}

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

function Get_Doc_Title {
    # Specifically for PDFs, attempts to find the internal Title
    local title=$(grep -a "/Title" "$1" | head -n 1 | sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_')
    if [ -z "$title" ]; then
        Get_File_Name "$1"
    else
        echo "$title"
    fi
}

function Get_Image_Meta {
    # Extracts Camera Model or Image Description
    local model=$(timeout 5s identify -format "%[standard:make] %[standard:model]" "$1" 2>/dev/null)
    if [ -z "$model" ] || [ "$model" = " " ]; then
        Get_File_Name "$1"
    else
        echo "$model" | tr -d '/\\:*?"<>|' | tr ' ' '_'
    fi
}

function Get_Audio_Info {
    # Extracts Artist - Title from audio metadata
    local info=$(timeout 5s ffprobe -v error -show_entries format_tags=artist,title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null | tr '\n' '-' | sed 's/-$//')
    if [ -z "$info" ]; then
        Get_File_Name "$1"
    else
        echo "$info" | tr -d '/\\:*?"<>|' | tr ' ' '_'
    fi
}

function Get_Video_Title {
    local title=$(timeout 10s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null)
    if [ -z "$title" ]; then
        Get_File_Name "$1"
    else
        # Clean title: Remove illegal chars and replace spaces with underscores
        echo "$title" | tr -d '/\\:*?"<>|' | tr ' ' '_'
    fi
}

function Resolve_Path_Segment {
	local Req="${1,,}" File="$2" Res=""
	case "$Req" in
		"year")           Res=$(Get_Date_Part "$File" "+%Y" "0000") ;;
		"month")          Res=$(Get_Date_Part "$File" "+%m" "00") ;;
		"day")            Res=$(Get_Date_Part "$File" "+%d" "00") ;;
		"year+month")     Res=$(Get_Date_Part "$File" "+%Y/%m" "0000/00") ;;
		"year+month+day") Res=$(Get_Date_Part "$File" "+%Y/%m/%d" "0000/00/00") ;;
		"extension")      local e=$(Get_File_Ext "$File"); Res=${e^^} ;;
		"mime")           Res=${MIME^^} ;;
		"mime-main")      Res=${MIMEMain^^} ;;
		"mime-sub")       Res=${MIMESub^^} ;;
		"size"|"format"|"size+format"|"format+size")
			if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
				local WxH=$([ "$MIMEMain" == "image" ] && Get_Image_WxH "$File" || Get_Video_WxH "$File")
				local Fmt=$(Get_WxH_Format "$WxH")
				[[ "$Req" == "size" ]] && Res="$WxH" || { [[ "$Req" == "format" ]] && Res="$Fmt" || Res="$Fmt/$WxH"; }
			else
				local S=$(Get_File_Size "$File")
				S=${S:-0}
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
					"size") Res="$T${U[$N]}" ;;
					"size+format") Res="${T}_${U[$N]}" ;;
					"format") Res="${U[$N]}" ;;
					"format+size") Res="${U[$N]}/$T" ;;
				esac
			fi ;;
		"created") Res=$(Get_File_Creation_Time "$File") ;;
		"modified") Res=$(Get_File_Modification_Time "$File") ;;
		"accessed") Res=$(Get_File_Access_Time "$File") ;;
		"shasum"|"sha1deep"|"sha1sum"|"sha224sum"|"sha256deep"|"sha256sum"|"sha384sum"|"sha512sum") Res=$(/usr/bin/$Req -b "$File" | cut -d' ' -f1) ;;
		"random") Res="${RANDOM}${RANDOM}" ;;
		*) Res="$1" ;;
	esac
	printf "$Res"
}

function Draw_Line {
	local w=$(tput cols) s="${1:-=}"
	printf -v l "%${w}s" ""
	echo "${l// /$s}" | cut -c 1-"$w"
}

# --- Main Logic ---

declare -a Total Counter
Current=0

function Sort {
	((Current++))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		case "${Item,,}" in
			"--pause="*)     ((Total[$Current]--)); Pause=${Item#*=};;
			"--type="*)      ((Total[$Current]--)); Type=${Item#*=};;
			"--mode="*)      ((Total[$Current]--)); Mode=${Item#*=};; # combined copy/move/remove
			"--recursive")   ((Total[$Current]--)); Recursive="yes";;
			"--replace")     ((Total[$Current]--)); Replace="yes";;
			"--rename="*)    ((Total[$Current]--)); Rename=${Item#*=};;
			"--title")       ((Total[$Current]--)); Title="yes";;
			"--extension="*) ((Total[$Current]--)); Extension=${Item#*=};;
			"--dirs="*)      ((Total[$Current]--)); Dirs=${Item#*=};;
			"--subdirs="*)   ((Total[$Current]--)); SubDirs=${Item#*=};;
			*)
			((Counter[$Current]++))
			printf "PROGRESS"
			for (( i=1; i<=$Current; i++ )); do printf " ~ [$i]=${Counter[$i]}/${Total[$i]}"; done; printf "\n"

			if [[ ! -e "$Item" ]]; then printf "SKIP: Missing $Item\n"
			elif [[ -L "$Item" ]]; then printf "SKIP: Symlink $Item\n"
			elif [[ -d "$Item" ]]; then
				Draw_Line "="
				if [ "$Recursive" = "yes" ]; then
					printf "$BOLDBLUE DIR:$YELLOW $Item$RESET\n"
					Draw_Line ">"
					Sort "$Item"/*
					if [ "$Mode" = "move" ]; then
						local CleanupLog
						CleanupLog=$(rmdir -v "$Item" 2>&1)

						if [ $? -eq 0 ]; then
							printf "$BLUE CLEANUP:$RESET %s\n" "$CleanupLog"
						else
							Log "$RED ERROR:$RESET Directory not empty, skipping cleanup: $Item"
						fi
					fi
				else
					printf "$RED DIR:$RESET Skipping!\n"
				fi
				Draw_Line "="
			elif [[ -f "$Item" ]]; then
				Draw_Line "-"
				printf "$BOLDGREEN FILE:$YELLOW $Item$RESET\n"

				MIME=$(Get_MIME "$Item")
				MIMEMain=${MIME%/*}
				MIMESub=${MIME#*/}
				printf "$YELLOW MIME:$RESET $MIME\n"

				if [ -z "$Type" ] || [[ "${MIME^^}" == *"${Type^^}"* ]]; then
					# Build Target Path
					D=$(Resolve_Path_Segment "$Dirs" "$Item")
					SD=$([ -n "$SubDirs" ] && Resolve_Path_Segment "$SubDirs" "$Item" || printf "")

					Loc="."
					[ -n "$D" ] && Loc="${D^^}"
					[ -n "$SD" ] && Loc="$Loc/${SD^^}"

					printf "$YELLOW TARGET:$RESET $Loc\n"

					# Build Target Name
					if [ -n "$Title" ] ; then
						case "${MIMEMain,,}" in
						"application") Name=$(Get_Doc_Title "$Item");;
						"image")       Name=$(Get_Image_Meta "$Item");;
						"audio")       Name=$(Get_Audio_Info "$Item");;
						"video")       Name=$(Get_Video_Title "$Item");;
						esac
					fi
					[ -z "$Name" ] && Name=$(Get_File_Name "$Item")

					[ -n "$Rename" ] && Name=$(Resolve_Path_Segment "$Rename" "$Item")
					Ext=$(Get_File_Ext "$Item")
					if [ -n "$Extension" ]; then
						Ext=$(Resolve_Path_Segment "$Extension" "$Item")
						Ext=${Ext,,}
						Ext=${Ext//\//.}
						Ext=${Ext// /_}
					fi

					NewName="$Name.$Ext"
					if [ -z "$Replace" ] || [ -z "$Title" ]; then
						C=0
						BaseName="$Name"
						while [ -e "$Loc/$NewName" ]; do
							((C++))
							NewName="$BaseName-($C).$Ext"
						done
					fi

					printf "$YELLOW NEW-NAME:$RESET $NewName\n"

					# Action
					if [ -n "$Mode" ]; then
						printf "$YELLOW MKDIR:$RESET %s\n" "$(mkdir -v -p "$Loc")"

						case "$Mode" in
							"move")   printf "$RED MOVE:$RESET %s\n"   "$(mv -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
							"copy")   printf "$RED COPY:$RESET %s\n"   "$(cp -v -f "$Item" "$Loc/$NewName" 2>&1)" ;;
							"remove") printf "$RED REMOVE:$RESET %s\n" "$(trash-put -v "$Item" 2>&1)" ;;
						esac					else
						printf "$GREEN TEST:$RESET $Item -> $Loc/$NewName\n"
					fi
					[ -n "$Pause" ] && sleep "$Pause"

					Draw_Line "-"
				fi
			fi ;;
		esac
	done
	((Current--))
}

# Execution
if [ $# -gt 0 ]; then
	Sort "$@"

	printf "\n$GREEN---DONE---$RESET\n\n"

	IFS=$OIFS
else
	# Clear the screen or draw a line for better presentation
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
	--mode=remove     Deletes the target files permanently.

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
