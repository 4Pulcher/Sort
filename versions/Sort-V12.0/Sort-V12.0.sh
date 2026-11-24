#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V12.0.sh                                                     #
# Version : 12.0                                                              #
# Desc    : Threaded file organizer with logging                              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# ==============================================================================
# Sort.sh v4.0 (Threadded) - Media-Intelligent File Organizer with Multi-Threading (--jobs=N)
# Developed by: HEjder
#
# PURPOSE:
#   Organizes files using MIME types, filesystem timestamps, checksums, and
#   optional media metadata[cite: 6]. Supports concurrent parallel processing
#   via background subshells throttled by the --jobs=N parameter.
# ==============================================================================

# ==============================================================================
# 1. TERMINAL COLORS & STYLING
# ==============================================================================
BOLD='\e[1m'
BLUE='\e[34m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'

BOLDBLUE='\e[1;34m'
BOLDGREEN='\e[1;32m'
BOLDRED='\e[1;31m'
BOLDYELLOW='\e[1;33m'
RESET='\e[0m'

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
		printf '%bERROR:%b Command "%s" is missing. Install package: %s\n' \
			"$RED" "$RESET" "$Key" "${Required[$Key]}"
		((Errors += 1))
	else
		printf '%bOK:%b Command "%s" is available.\n' \
			"$GREEN" "$RESET" "$Key"
	fi
done

if ((Errors > 0)); then
	printf '\n%bERROR:%b %d required command(s) missing; cannot continue.\n' \
		"$RED" "$RESET" "$Errors"
	exit 1
fi

# ==============================================================================
# 3. GLOBAL CONFIGURATION & SIGNAL TRAPS
# ==============================================================================
OIFS=$IFS
Mode=""

# User-configurable options
Type=""
Recursive="no"
Dirs=""
SubDirs=""
Rename=""
Title=""
Extension=""
Replace="no"
Pause=""

# Concurrency setting (--jobs=N). Defaults to 4 concurrent background jobs.
MAX_JOBS=4
Compare="no"

declare -a Total Counter
Current=0

# Exit: exit
Exit() {
	local Status=${1:-0}
	trap - EXIT

	printf 'Waiting for all background jobs to finish...\n'
	wait

	IFS=$OIFS
	printf 'Finished.\n'
	exit "$Status"
}

# Break: break
Break() {
	printf '\nTerminated by user!\n'
	Exit 130
}

trap 'Exit $?' EXIT
trap Break INT

shopt -s dotglob nullglob

# ==============================================================================
# 4. FILE ATTRIBUTE & CHECKSUM HELPERS
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

	if [[ ! -x "/usr/bin/$CommandName" ]]; then
		printf 'ERROR'
		return 1
	fi

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
	local File=$1
	local Size
	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}

# Get_File_Birth: get file birth
Get_File_Birth() {
	local File=$1
	local Time
	Time=$(stat -c '%W' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

# Get_File_Creation_Time: get file creation time
Get_File_Creation_Time() {
	local File=$1
	stat -c '%w' -- "$File" 2>/dev/null
}

# Get_File_Access_Time: get file access time
Get_File_Access_Time() {
	local File=$1
	stat -c '%x' -- "$File" 2>/dev/null
}

# Get_File_Modification_Time: get file modification time
Get_File_Modification_Time() {
	local File=$1
	stat -c '%y' -- "$File" 2>/dev/null
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
# 5. MEDIA & DOCUMENT METADATA EXTRACTORS
# ==============================================================================
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

# Get_Media_WxH: get media wx h
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
	Resolution=${Resolution%x}
	printf '%s' "${Resolution:-0x0}"
}

# Get_WxH_Format: get wx h format
Get_WxH_Format() {
	local Input=$1
	local Width Height MaxDimension
	local Level="TINY"
	local Aspect="SQUARE"

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

# Get_Image_Meta: get image meta
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
# 6. DYNAMIC KEYWORD RESOLVER
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
# 7. TERMINAL UI HELPERS
# ==============================================================================
Draw_Line() {
	local Width Symbol
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	Symbol=${1:-=}
	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
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

# Validate_Options: validate options
Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf '%bERROR:%b Unsupported mode: %s\n' "$RED" "$RESET" "$Mode"
		return 1
		;;
	esac

	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf '%bERROR:%b --pause must be a non-negative number of seconds.\n' "$RED" "$RESET"
		return 1
	fi

	# Validate MAX_JOBS is a positive integer
	if [[ -n "$MAX_JOBS" && ! "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
		printf '%bERROR:%b --jobs value must be a positive integer.\n' "$RED" "$RESET"
		return 1
	fi

	[[ "$Compare" == "yes" ]] &&
		printf '%bWARNING:%b --compare is currently not implemented.\n' "$YELLOW" "$RESET"

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
Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	if [[ -z "$Mode" ]]; then
		printf '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}"; then
			printf '%bERROR:%b Could not create destination directory.\n' "$RED" "$RESET"
			return 1
		fi
	fi

	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)

		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				printf '%bERROR:%b Source and target are same file; refusing destructive action: %s\n' \
					"$RED" "$RESET" "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	case "$Mode" in
	copy)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			printf '%bERROR:%b Destination exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		}
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		[[ -e "$TargetPath" && "$Replace" != "yes" ]] && {
			printf '%bERROR:%b Destination exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		}
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		[[ -e "$TargetPath" ]] && rm -v -f -- "$TargetPath" || {
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		}
		;;
	trash)
		[[ -e "$TargetPath" ]] && trash-put -- "$TargetPath" || {
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		}
		;;
	shred)
		[[ -e "$TargetPath" ]] && shred -u -n 1 -- "$TargetPath" || {
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		}
		;;
	esac
}

# ==============================================================================
# 10. MAIN RECURSIVE FILE PROCESSOR (WITH THREADING / --jobs=N)
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

		printf 'PROGRESS'

		local Level

		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				Children=("$Item"/*)
				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

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

		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# ----------------------------------------------------------------------
		# MULTI-THREADED FILE EXECUTION BLOCK (Spawned in background if MAX_JOBS > 1)
		# ----------------------------------------------------------------------
		(
			Draw_Line '-'
			printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

			MIME=$(Get_MIME "$Item")
			MIMEMain=${MIME%%/*}
			MIMESub=${MIME#*/}

			printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

			if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
				printf '%bSKIP:%b MIME type does not match --type=%s\n' \
					"$YELLOW" "$RESET" "$Type"
				Draw_Line '-'
				exit 0
			fi

			# Step 1: Destination Directory
			if [[ -n "$Dirs" ]]; then
				DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
			else
				DestinationDir=${Item%/*}
				[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
			fi

			SubDirectory=""
			if [[ -n "$SubDirs" ]]; then
				SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
			fi

			[[ -z "$DestinationDir" ]] && DestinationDir="."
			if [[ -n "$SubDirectory" ]]; then
				DestinationDir="${DestinationDir%/}/$SubDirectory"
			fi

			printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

			# Step 2: Filename
			FileName=$(Get_File_Name "$Item")
			if [[ -n "$Rename" ]]; then
				TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
					FileName=$TemporaryName
			fi

			if [[ "$Title" == "yes" ]]; then
				TemporaryName=""
				case "${MIMEMain,,}" in
				application) TemporaryName=$(Get_Doc_Title "$Item") ;;
				image) TemporaryName=$(Get_Image_Meta "$Item") ;;
				audio) TemporaryName=$(Get_Audio_Info "$Item") ;;
				video) TemporaryName=$(Get_Video_Title "$Item") ;;
				esac
				[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
					FileName=$TemporaryName
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

			# Step 3: Collision Management
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

			# Step 4: Perform Action
			Perform_Action "$Item" "$TargetPath"

			if [[ -n "$Pause" ]]; then
				sleep "$Pause"
			fi

			Draw_Line '-'
		) &

		# --- CONCURRENCY THROTTLE ---
		# If MAX_JOBS > 1, wait until active background job count drops below MAX_JOBS
		if ((MAX_JOBS > 1)); then
			while (($(jobs -r | wc -l) >= MAX_JOBS)); do
				sleep 0.1
			done
		fi
	done

	((Current -= 1))
}

# ==============================================================================
# 11. CLI USAGE & DOCUMENTATION
# ==============================================================================
Show_Help() {
	Draw_Line '━'
	cat <<'EOF'
Sort.sh v2.2 - Media-Intelligent File Organizer with --jobs=N Threading
Organizes files using MIME information, filesystem timestamps and metadata.

USAGE
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

OPERATION MODES
  --mode=copy       Copy files to calculated destination.
  --mode=move       Move files to calculated destination.
  --mode=delete     Permanently delete target file.
  --mode=trash      Send target file to desktop trash.
  --mode=shred      Securely overwrite and delete target file.

PROCESSING & THREADING
  --jobs=N          Run up to N tasks in parallel (default: 4).
  --type=VALUE      Filter files by MIME type (e.g. image, video, pdf).
  --recursive       Process subdirectories recursively.
  --pause=SEC       Wait specified seconds after each file action.

DESTINATION & NAMING
  --dirs=OPT        Primary directory structure pattern.
  --subdirs=OPT     Secondary subdirectory pattern.
  --rename=OPT      Override filename with dynamic value.
  --extension=OPT   Override file extension with dynamic value.
  --title           Extract smart metadata for titles (Video, Audio, Image, PDF).
  --replace         Overwrite existing files at destination.

EOF
	Draw_Line '━'
}

# ==============================================================================
# 12. SCRIPT ENTRY POINT
# ==============================================================================
if (($# == 0)); then
	Show_Help
	exit 0
fi

Parse_Arguments "$@"

if ! Validate_Options; then
	exit 2
fi

if ((${#InputItems[@]} == 0)); then
	printf '%bERROR:%b No input files or directories were supplied.\n' "$RED" "$RESET"
	exit 2
fi

# Run sorting workflow
Sort "${InputItems[@]}"

# Wait for all parallel background jobs to finish before finishing
wait

printf '\n%b--- DONE --- %b\n\n' "$GREEN" "$RESET"
echo "Thanks for using HEjder scripts!"
exit 0