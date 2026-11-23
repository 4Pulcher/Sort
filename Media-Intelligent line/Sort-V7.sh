#!/usr/bin/env bash
# ==============================================================================
# Sort.sh v6 (Threads, Logs, Display, Exif) - Media-Intelligent File Organizer with ExifTool Integration
# Developed by: Ali_ISIN
#
# PURPOSE:
#   Organizes, renames, and sorts files based on MIME types, EXIF/media tags,
#   cryptographic hashes, and filesystem attributes.
# ==============================================================================


# ==============================================================================
# 1. TERMINAL COLORS & UI CONFIGURATION
# ==============================================================================
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

ENABLE_COLORS="no"
ENABLE_LOG="no"
LOG_FILE=""
TUI_ACTIVE="no"
HEADER_ROWS=8


# ==============================================================================
# 2. SYSTEM DEPENDENCY CHECK (Including ExifTool)
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
    [exiftool]="libimage-exiftool-perl"
    [ffprobe]="ffmpeg"
    [identify]="imagemagick"
    [tput]="ncurses-bin / ncurses"
)

Errors=0
for Key in "${!Required[@]}"; do
    if ! command -v "$Key" >/dev/null 2>&1; then
        printf 'ERROR: Command "%s" is missing. Install package: %s\n' \
            "$Key" "${Required[$Key]}"
        (( Errors += 1 ))
    fi
done

if (( Errors > 0 )); then
    printf '\nERROR: %d required command(s) missing; cannot continue.\n' "$Errors"
    exit 1
fi


# ==============================================================================
# 3. GLOBAL DEFAULTS, SLOT POOL & SIGNAL TRAPS
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
SLOT_DIR=""

Exit() {
    local Status=${1:-0}
    trap - EXIT
    wait
    if [[ "$TUI_ACTIVE" == "yes" ]]; then
        local BottomRow=$(( HEADER_ROWS + MAX_JOBS + 3 ))
        printf '\033[%d;1H\033[?25h\n' "$BottomRow"
    fi
    [[ -n "$SLOT_DIR" && -d "$SLOT_DIR" ]] && rm -rf -- "$SLOT_DIR"
    IFS=$OIFS
    exit "$Status"
}

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

Init_TUI() {
    TUI_ACTIVE="yes"
    local Width
    Width=$(tput cols 2>/dev/null)
    Width=${Width:-80}

    local Rule
    printf -v Rule '%*s' "$Width" ''
    Rule=${Rule// /=}

    printf '\033[2J\033[1;1H\033[?25l'
    printf '%b%s%b\n' "$BLUE" "$Rule" "$RESET"
    printf '%b  Sort.sh v2.5%b | Media-Intelligent File Organizer (ExifTool Enabled)\n' "$BOLD" "$RESET"
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

    local Slot
    for (( Slot=1; Slot<=MAX_JOBS; Slot++ )); do
        local Row=$(( HEADER_ROWS + Slot ))
        printf '\033[%d;1H\033[K  %b[Thread %02d]%b %bIDLE%b\n' \
            "$Row" "$CYAN" "$Slot" "$RESET" "$DIM" "$RESET"
    done

    local FooterRow=$(( HEADER_ROWS + MAX_JOBS + 1 ))
    printf '\033[%d;1H\033[K%b%s%b\n' "$FooterRow" "$BLUE" "$Rule" "$RESET"
}

Update_Thread_Slot() {
    local SlotID=$1 Badge=$2 BadgeColor=$3 Detail=$4
    local TargetRow=$(( HEADER_ROWS + SlotID ))
    local Width MaxDetail
    Width=$(tput cols 2>/dev/null)
    Width=${Width:-80}
    MaxDetail=$(( Width - 28 ))
    (( MaxDetail < 20 )) && MaxDetail=20
    if (( ${#Detail} > MaxDetail )); then
        Detail="...${Detail: -$((MaxDetail - 3))}"
    fi

    (
        flock -x 201
        printf '\033[%d;1H\033[K  %b[Thread %02d]%b %b%-10s%b %s' \
            "$TargetRow" "$CYAN" "$SlotID" "$RESET" "$BadgeColor" "$Badge" "$RESET" "$Detail"
    ) 201>"$SLOT_DIR/tty.lock"
}

Update_Header_Dir() {
    local CurrentDir=$1
    local StatusRow=$(( HEADER_ROWS + MAX_JOBS + 2 ))
    local Width MaxLen
    Width=$(tput cols 2>/dev/null)
    Width=${Width:-80}
    MaxLen=$(( Width - 18 ))
    (( MaxLen < 20 )) && MaxLen=20

    if (( ${#CurrentDir} > MaxLen )); then
        CurrentDir="...${CurrentDir: -$((MaxLen - 3))}"
    fi

    (
        flock -x 201
        printf '\033[%d;1H\033[K  %bScanning:%b %s' \
            "$StatusRow" "$BLUE" "$RESET" "$CurrentDir"
    ) 201>"$SLOT_DIR/tty.lock"
}

Acquire_Slot() {
    local Slot
    while true; do
        for (( Slot=1; Slot<=MAX_JOBS; Slot++ )); do
            if mkdir "$SLOT_DIR/slot_$Slot" 2>/dev/null; then
                printf '%d' "$Slot"
                return 0
            fi
        done
        sleep 0.05
    done
}

Release_Slot() {
    local Slot=$1
    rmdir "$SLOT_DIR/slot_$Slot" 2>/dev/null
}


# ==============================================================================
# 5. FILE ATTRIBUTE & CHECKSUM HELPERS
# ==============================================================================
Get_MD5Sum() {
    md5sum -b -- "$1" 2>/dev/null | cut -d' ' -f1
}

Get_SHA_Keys() {
    local CommandName=$1 File=$2
    [[ ! -x "/usr/bin/$CommandName" ]] && { printf 'ERROR'; return 1; }
    /usr/bin/"$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1
}

Get_SHA256Sum() {
    sha256sum -b -- "$1" 2>/dev/null | cut -d' ' -f1
}

Get_MIME() {
    file -b --mime-type -- "$1" 2>/dev/null
}

Get_File_Name() {
    local Name=${1##*/}
    printf '%s' "${Name%.*}"
}

Get_File_Ext() {
    local BaseName=${1##*/}
    if [[ "$BaseName" != *.* || ( "$BaseName" == .* && "$BaseName" != *.*.* ) ]]; then
        printf ''
    else
        printf '%s' "${BaseName##*.}"
    fi
}

Get_File_Size()                  { stat -c '%s' -- "$1" 2>/dev/null; }
Get_File_Birth()                 { stat -c '%W' -- "$1" 2>/dev/null; }
Get_File_Creation_Time()         { stat -c '%w' -- "$1" 2>/dev/null; }
Get_File_Access_Time()           { stat -c '%x' -- "$1" 2>/dev/null; }
Get_File_Modification_Time()     { stat -c '%y' -- "$1" 2>/dev/null; }

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
# 6. EXIFTOOL-FIRST METADATA & DATE EXTRACTORS
# ==============================================================================

# Extract a specific tag via ExifTool safely
Get_Exif_Tag() {
    local File=$1
    local TagName=$2
    exiftool -s -s -s -"$TagName" "$File" 2>/dev/null
}

# Preferred Date/Time extractor: Uses ExifTool first, falls back to birth time
Get_Image_Meta() {
    local File=$1
    local Date

    # 1. Try ExifTool common date tags (DateTimeOriginal, CreateDate, ModifyDate)
    Date=$(Get_Exif_Tag "$File" DateTimeOriginal)
    [[ -z "$Date" ]] && Date=$(Get_Exif_Tag "$File" CreateDate)
    [[ -z "$Date" ]] && Date=$(Get_Exif_Tag "$File" ModifyDate)

    # 2. Fall back to ffprobe if ExifTool returned nothing
    if [[ -z "$Date" ]]; then
        Date=$(
            timeout 5s ffprobe -v error \
                -show_entries format_tags=date_time_original \
                -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null
        )
    fi

    # 3. Final fallback to filesystem creation time
    [[ -z "$Date" ]] && Date=$(Get_File_Creation_Time "$File")

    # Sanitize characters unsafe for filenames
    printf '%s' "${Date:-ERROR}" | tr -d '/\\:*?"<>|'
}

# Preferred Audio Info extractor: Uses ExifTool first for Artist/Album/Title
Get_Audio_Info() {
    local File=$1
    local Artist Album Title Info=""

    Artist=$(Get_Exif_Tag "$File" Artist)
    Album=$(Get_Exif_Tag "$File" Album)
    Title=$(Get_Exif_Tag "$File" Title)

    # Fallback to ffprobe if tags are missing via ExifTool
    if [[ -z "$Artist" ]]; then
        Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
    fi
    if [[ -z "$Album" ]]; then
        Album=$(timeout 10s ffprobe -v error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
    fi
    if [[ -z "$Title" ]]; then
        Title=$(timeout 5s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
    fi

    [[ -n "$Artist" ]] && Info=$Artist
    [[ -n "$Album"  ]] && Info="${Info:+$Info - }$Album"
    [[ -n "$Title"  ]] && Info="${Info:+$Info - }$Title"

    printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# Preferred Video Title extractor: Uses ExifTool first, falls back to ffprobe
Get_Video_Title() {
    local File=$1
    local Title Artist Info=""

    Title=$(Get_Exif_Tag "$File" Title)
    Artist=$(Get_Exif_Tag "$File" Artist)

    [[ -z "$Title" ]] && Title=$(timeout 10s ffprobe -v error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)
    [[ -z "$Artist" ]] && Artist=$(timeout 10s ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$File" 2>/dev/null)

    [[ -n "$Artist" ]] && Info=$Artist
    [[ -n "$Title"  ]] && Info="${Info:+$Info - }$Title"

    printf '%s' "$Info" | tr -d '/\\:*?"<>|'
}

# PDF Document Title: ExifTool first, falls back to grep scan
Get_Doc_Title() {
    local File=$1
    local Title

    Title=$(Get_Exif_Tag "$File" Title)
    [[ -z "$Title" ]] && Title=$(grep -a '/Title' "$1" 2>/dev/null | head -n 1 | sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_')
    [[ -z "$Title" ]] && Title=$(Get_File_Name "$1")

    printf '%s' "${Title:-ERROR}" | tr -d '/\\:*?"<>|'
}


# ==============================================================================
# 7. IMAGE & MEDIA DIMENSION HELPERS
# ==============================================================================
Get_Image_WxH() {
    local Resolution
    # ExifTool preferred for image dimensions, ImageMagick fallback
    Resolution=$(Get_Exif_Tag "$1" ImageSize)
    [[ -z "$Resolution" ]] && Resolution=$(identify -ping -format '%wx%h\n' -- "$1" 2>/dev/null | head -n 1 | tr -d '\r\n ')
    Resolution=${Resolution// /x}
    printf '%s' "${Resolution:-0x0}"
}

Get_Media_WxH() {
    local Resolution
    Resolution=$(Get_Exif_Tag "$1" ImageSize)
    [[ -z "$Resolution" ]] && Resolution=$(
        timeout 10s ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height -of csv=s=x:p=0 "$1" 2>/dev/null
    )
    Resolution=${Resolution%x}
    Resolution=${Resolution// /x}
    printf '%s' "${Resolution:-0x0}"
}

Get_WxH_Format() {
    local Input=$1
    local Width Height MaxDimension
    local Level="TINY" Aspect="SQUARE"

    [[ ! "$Input" =~ ^[0-9]+x[0-9]+$ ]] && { printf 'ERROR'; return 1; }
    [[ "$Input" == "0x0" ]] && { printf 'ZERO'; return 0; }

    Width=${Input%%x*}
    Height=${Input##*x}
    MaxDimension=$Width
    (( Height > Width )) && MaxDimension=$Height

    (( MaxDimension > 32 ))    && Level="MINI"
    (( MaxDimension > 512 ))   && Level="SMALLER"
    (( MaxDimension > 1024 ))  && Level="SMALL"
    (( MaxDimension > 2048 ))  && Level="MEDIUM"
    (( MaxDimension > 4096 ))  && Level="BIG"
    (( MaxDimension > 8192 ))  && Level="BIGGER"
    (( MaxDimension > 16384 )) && Level="HUGE"

    (( Width > Height )) && Aspect="WIDE"
    (( Width < Height )) && Aspect="HIGH"

    printf '%s/%s' "$Level" "$Aspect"
}


# ==============================================================================
# 8. DYNAMIC KEYWORD RESOLVER
# ==============================================================================
Resolve_Path_Segment() {
    local Req=${1,,}
    local File=$2

    case "$Req" in
        year)           Get_Date_Part "$File" '+%Y' '0000' ;;
        month)          Get_Date_Part "$File" '+%m' '00' ;;
        day)            Get_Date_Part "$File" '+%d' '00' ;;
        year+month)     Get_Date_Part "$File" '+%Y/%m' '0000/00' ;;
        year+month+day) Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00' ;;
        created)        Get_File_Creation_Time "$File" ;;
        modified)       Get_File_Modification_Time "$File" ;;
        accessed)       Get_File_Access_Time "$File" ;;
        extension)      Get_File_Ext "$File" ;;
        mime)           printf '%s' "${MIME^^}" ;;
        mime-main)      printf '%s' "${MIMEMain^^}" ;;
        mime-sub)       printf '%s' "${MIMESub^^}" ;;

        size|format|size+format|format+size)
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

                while (( Value >= Divisor && UnitIndex < ${#Units[@]} - 1 )); do
                    (( UnitIndex += 1 ))
                    Value=$(( Value / Divisor ))
                done

                case "$Req" in
                    size)        printf '%s%s' "$Value" "${Units[$UnitIndex]}" ;;
                    size+format) printf '%s_%s' "$Value" "${Units[$UnitIndex]}" ;;
                    format)      printf '%s' "${Units[$UnitIndex]}" ;;
                    format+size) printf '%s/%s' "${Units[$UnitIndex]}" "$Value" ;;
                esac
            fi
            ;;

        md5|md5sum)     Get_MD5Sum "$File" ;;
        sha)            Get_SHA_Keys shasum "$File" ;;
        sha1|sha224|sha256|sha384|sha512) Get_SHA_Keys "${Req}sum" "$File" ;;
        shasum|sha1deep|sha1sum|sha224sum|sha256deep|sha256sum|sha384sum|sha512sum) Get_SHA_Keys "$Req" "$File" ;;

        random*)
            local Count=${Req#random}
            if [[ -z "$Count" ]]; then
                printf '%s' "$RANDOM"
            elif [[ "$Count" =~ ^[0-9]+$ ]]; then
                while (( Count > 0 )); do
                    printf '%s' "$RANDOM"
                    (( Count -= 1 ))
                done
            else
                printf 'ERROR'
                return 1
            fi
            ;;
        *) printf 'ERROR'; return 1 ;;
    esac
}


# ==============================================================================
# 9. CLI ARGUMENT PARSING & VALIDATION
# ==============================================================================
declare -a InputItems=()

Parse_Arguments() {
    local Argument
    for Argument in "$@"; do
        case "${Argument,,}" in
            --copy)        Mode="copy" ;;
            --move)        Mode="move" ;;
            --delete)      Mode="delete" ;;
            --remove)      Mode="remove" ;;
            --trash)       Mode="trash" ;;
            --shred)       Mode="shred" ;;
            --mode=*)      Mode=${Argument#*=}; Mode=${Mode,,} ;;
            --type=*)      Type=${Argument#*=} ;;
            --recursive)   Recursive="yes" ;;
            --pause=*)     Pause=${Argument#*=} ;;
            --dirs=*)      Dirs=${Argument#*=} ;;
            --subdirs=*)   SubDirs=${Argument#*=} ;;
            --rename=*)    Rename=${Argument#*=} ;;
            --extension=*) Extension=${Argument#*=} ;;
            --title)       Title="yes" ;;
            --replace)     Replace="yes" ;;
            --jobs=*)      MAX_JOBS=${Argument#*=} ;;
            --compare)     Compare="yes" ;;
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
                printf '=== Sort.sh v2.5 Log Started: %s ===\n' "$(date)" > "$LOG_FILE"
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

Validate_Options() {
    case "$Mode" in
        ""|copy|move|delete|remove|trash|shred) ;;
        *) printf 'ERROR: Unsupported mode: %s\n' "$Mode"; return 1 ;;
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
# 10. FILESYSTEM ACTION EXECUTOR
# ==============================================================================
Perform_Action() {
    local SourcePath=$1 TargetPath=$2 SlotID=$3
    local SourceReal TargetReal

    if [[ -z "$Mode" ]]; then
        Update_Thread_Slot "$SlotID" "DRY-RUN" "$BLUE" "$SourcePath -> $TargetPath"
        Write_Log "TEST: $SourcePath -> $TargetPath"
        return 0
    fi

    if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
        if ! mkdir -p -- "${TargetPath%/*}" 2>/dev/null; then
            Update_Thread_Slot "$SlotID" "ERROR" "$RED" "Failed creating dir: ${TargetPath%/*}"
            Write_Log "ERROR: Could not create directory for $TargetPath"
            return 1
        fi
    fi

    if [[ -e "$TargetPath" ]]; then
        SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
        TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)
        if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
            case "$Mode" in
                delete|remove|trash|shred)
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
        delete|remove)
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
# 11. MAIN RECURSIVE FILE PROCESSOR
# ==============================================================================
Sort() {
    local Item
    local -a Children

    (( Current += 1 ))
    Total[$Current]=$#
    Counter[$Current]=0

    for Item in "$@"; do
        (( Counter[$Current] += 1 ))

        [[ ! -e "$Item" && ! -L "$Item" ]] && { Write_Log "SKIP: Missing $Item"; continue; }
        [[ -L "$Item" ]] && { Write_Log "SKIP: Symlink $Item"; continue; }

        if [[ -d "$Item" ]]; then
            Update_Header_Dir "$Item"
            if [[ "$Recursive" == "yes" ]]; then
                Write_Log "DIR: Entering $Item"
                Children=("$Item"/*)
                (( ${#Children[@]} > 0 )) && Sort "${Children[@]}"

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

        local AssignedSlot
        AssignedSlot=$(Acquire_Slot)

        (
            trap 'Release_Slot "$AssignedSlot"' EXIT

            Update_Thread_Slot "$AssignedSlot" "ANALYZING" "$YELLOW" "$Item"

            local MIME MIMEMain MIMESub
            MIME=$(Get_MIME "$Item")
            MIMEMain=${MIME%%/*}
            MIMESub=${MIME#*/}

            if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
                Update_Thread_Slot "$AssignedSlot" "SKIPPED" "$DIM" "MIME mismatch ($MIME): ${Item##*/}"
                Write_Log "SKIP (MIME $MIME): $Item"
                exit 0
            fi

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
                    image)       TemporaryName=$(Get_Image_Meta "$Item") ;;
                    audio)       TemporaryName=$(Get_Audio_Info "$Item") ;;
                    video)       TemporaryName=$(Get_Video_Title "$Item") ;;
                endcase
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
                    (( CollisionIndex += 1 ))
                    NewName="${TargetBase}-(${CollisionIndex})${TargetExtension}"
                    TargetPath="${DestinationDir%/}/$NewName"
                    [[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"
                done
            fi

            Perform_Action "$Item" "$TargetPath" "$AssignedSlot"

            [[ -n "$Pause" ]] && sleep "$Pause"
        ) &
    done

    (( Current -= 1 ))
}


# ==============================================================================
# 12. CLI USAGE & DOCUMENTATION
# ==============================================================================
Show_Help() {
    cat <<'EOF'
================================================================================
Sort.sh v2.5 - Media-Intelligent File Organizer (ExifTool Integration)
Developed by: Ali_ISIN
================================================================================

USAGE:
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

OPERATIONAL MODES:
  --mode=copy       Copy files to calculated destination.
  --mode=move       Move files to calculated destination.
  --mode=delete     Permanently delete target file (alias: --mode=remove).
  --mode=trash      Send target file to system trash (requires trash-cli).
  --mode=shred      Securely overwrite and delete target file.

DISPLAY, LOGGING & THREADING:
  --jobs=N          Number of concurrent worker threads (default: 4).
  --colors          Enable high-contrast ANSI colors for dark/light terminals.
  --log             Write a plain-text log to './Sort ~ YYYY-MM-DD.log'.

METADATA PREFERENCE:
  ExifTool is now the primary provider for:
    - Dates & Timestamps (DateTimeOriginal, CreateDate, ModifyDate)
    - Media Tags (Artist, Album, Title, ImageSize/Dimensions)
    - Automatically falls back to ffprobe/stat when tags are absent.
================================================================================
EOF
}


# ==============================================================================
# 13. SCRIPT ENTRY POINT
# ==============================================================================
if (( $# == 0 )); then
    Show_Help
    exit 0
fi

Parse_Arguments "$@"
Validate_Options || exit 2

if (( ${#InputItems[@]} == 0 )); then
    printf 'ERROR: No input files or directories were supplied.\n'
    exit 2
fi

SLOT_DIR=$(mktemp -d /tmp/sort_sh_slots.XXXXXX)

Init_TUI
Update_Header_Dir "Starting..."

Sort "${InputItems[@]}"

wait

for (( s=1; s<=MAX_JOBS; s++ )); do
    Update_Thread_Slot "$s" "DONE" "$GREEN" "Completed"
done
Update_Header_Dir "All tasks finished!"
Write_Log "=== Sort.sh v2.5 Finished: $(date) ==="

exit 0
