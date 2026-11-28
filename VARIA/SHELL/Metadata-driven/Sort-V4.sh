#!/bin/bash

# ============================================================
# Sort.sh
# Metadata-driven file organizer with safe copy/move/remove modes
# ============================================================

# ============================================================
# TERMINAL COLORS
# Human-readable labels, no icons
# ============================================================

BOLD='\e[1m'
DIM='\e[2m'
RESET='\e[0m'

COLOR_INFO='\e[36m'
COLOR_SUCCESS='\e[32m'
COLOR_WARNING='\e[33m'
COLOR_ERROR='\e[31m'
COLOR_LABEL='\e[94m'
COLOR_PATH='\e[37m'

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================

CFG_MODE='dummy'
CFG_RECURSIVE='no'
CFG_REPLACE='no'
CFG_PROBE='none'
CFG_TITLE='no'
CFG_TYPE=''
CFG_PAUSE=''
CFG_DIRS=''
CFG_SUBDIRS=''
CFG_RENAME=''
CFG_EXTENSION=''
CFG_SOURCE=''
CFG_TARGET='.'
CFG_LOG=''
CFG_SELF_TEST='no'

INPUTS=()
OIFS=$IFS

COUNT_PROCESSED=0
COUNT_COPIED=0
COUNT_MOVED=0
COUNT_REMOVED=0
COUNT_SKIPPED=0
COUNT_FAILED=0
COUNT_VERIFIED=0
COUNT_CLEANED_DIRS=0

# ============================================================
# REQUIREMENTS
# ============================================================

REQUIRED_COMMANDS=(
    file
    stat
    cp
    rm
    rmdir
    mkdir
    dirname
    realpath
    md5sum
    sha256sum
    ffprobe
    timeout
    tput
    date
    grep
    sed
    mktemp
)

function Check_Requirements {

    local Command

    for Command in "${REQUIRED_COMMANDS[@]}"; do

        if ! command -v "$Command" &>/dev/null; then
            Print_Error "Missing required command: $Command"
            exit 10
        fi

    done
}

# ============================================================
# OUTPUT AND LOGGING
# ============================================================

function Strip_Color {
    sed 's/\x1b\[[0-9;]*m//g'
}

function Log_Line {

    local Message="$1"

    [ -z "$CFG_LOG" ] && return 0

    printf '%b\n' "$Message" | Strip_Color >> "$CFG_LOG"
}

function Print_Line {

    local Message="$1"

    printf '%b\n' "$Message"
    Log_Line "$Message"
}

function Print_Info {
    Print_Line "${COLOR_INFO}INFO:${RESET} $1"
}

function Print_Success {
    Print_Line "${COLOR_SUCCESS}SUCCESS:${RESET} $1"
}

function Print_Warning {
    Print_Line "${COLOR_WARNING}WARNING:${RESET} $1"
}

function Print_Error {
    Print_Line "${COLOR_ERROR}ERROR:${RESET} $1"
}

function Print_Label {
    Print_Line "${COLOR_LABEL}$1:${RESET} $2"
}

# ============================================================
# SAFETY
# ============================================================

function Cleanup {
    IFS=$OIFS
}

function Break {
    Cleanup
    Print_Warning 'Interrupted by user.'
    exit 1
}

trap Break INT
trap Cleanup EXIT

shopt -s dotglob

# ============================================================
# BASIC HELPERS
# ============================================================

function Draw_Line {

    local Width
    local Char
    local Line

    Width=$(tput cols 2>/dev/null)
    Width=${Width:-80}
    Char="${1:-=}"

    printf -v Line '%*s' "$Width" ''
    Print_Line "${Line// /$Char}"
}

function Trim {

    local Value="$1"

    Value="${Value#${Value%%[![:space:]]*}}"
    Value="${Value%${Value##*[![:space:]]}}"

    printf '%s' "$Value"
}

function Normalize_Option_Value {

    local Value

    Value=$(Trim "$1")
    Value=${Value,,}

    printf '%s' "$Value"
}

# ============================================================
# FLEXIBLE TEMPLATE HELPERS
# ============================================================

function Slugify_Text {

    local Value="$1"

    Value=$(Trim "$Value")
    Value=$(Sanitize_File_Text "$Value")
    Value=${Value//__/_}
    Value=${Value##_}
    Value=${Value%%_}

    printf '%s' "$Value"
}

function Normalize_Path_Text {

    local Value="$1"

    Value=${Value//\//}
    Value=${Value//:/}
    Value=${Value//\*/}
    Value=${Value//\?/}
    Value=${Value//\"/}
    Value=${Value//</}
    Value=${Value//>/}
    Value=${Value//|/}
    Value=${Value// /_}

    while [[ "$Value" == *'//'* ]]; do
        Value=${Value//'//'/'/'}
    done

    Value=${Value#/}
    Value=${Value%/}

    printf '%s' "$Value"
}

function Format_Duration_HMS {

    local Seconds="$1"
    local Whole
    local H
    local M
    local S

    Whole=${Seconds%%.*}
    [[ "$Whole" =~ ^[0-9]+$ ]] || Whole=0

    H=$((Whole / 3600))
    M=$(((Whole % 3600) / 60))
    S=$((Whole % 60))

    printf '%02d-%02d-%02d' "$H" "$M" "$S"
}

function Format_Bitrate {

    local Bits="$1"

    [[ "$Bits" =~ ^[0-9]+$ ]] || {
        printf '%s' ''
        return
    }

    if [ "$Bits" -ge 1000000 ]; then
        printf '%sMbps' "$((Bits / 1000000))"
    elif [ "$Bits" -ge 1000 ]; then
        printf '%sKbps' "$((Bits / 1000))"
    else
        printf '%sbps' "$Bits"
    fi
}

function First_Non_Empty {

    local Value

    for Value in "$@"; do
        Value=$(Trim "$Value")
        [ -n "$Value" ] && {
            printf '%s' "$Value"
            return
        }
    done

    printf '%s' ''
}

function Sanitize_File_Text {

    local Value="$1"

    Value=${Value//\//}
    Value=${Value//\\/}
    Value=${Value//:/}
    Value=${Value//\*/}
    Value=${Value//\?/}
    Value=${Value//\"/}
    Value=${Value//</}
    Value=${Value//>/}
    Value=${Value//|/}
    Value=${Value// /_}

    printf '%s' "$Value"
}

function Get_Realpath_Existing {
    realpath -m -- "$1" 2>/dev/null
}

function Get_File_Name {

    local Base

    Base=${1##*/}

    if [[ "$Base" == *.* ]]; then
        printf '%s' "${Base%.*}"
    else
        printf '%s' "$Base"
    fi
}

function Get_File_Ext {

    local Base

    Base=${1##*/}

    if [[ "$Base" == *.* ]]; then
        printf '%s' "${Base##*.}"
    else
        printf '%s' ''
    fi
}

function Get_File_Size {

    local Size

    Size=$(stat -c %s -- "$1" 2>/dev/null)

    printf '%s' "${Size:-0}"
}

function Get_File_Birth {

    local Birth

    Birth=$(stat -c %W -- "$1" 2>/dev/null)

    printf '%s' "${Birth:-0}"
}

function Get_File_Creation_Time {
    stat -c %w -- "$1" 2>/dev/null
}

function Get_File_Access_Time {
    stat -c %x -- "$1" 2>/dev/null
}

function Get_File_Modification_Time {
    stat -c %y -- "$1" 2>/dev/null
}

function Get_Date_Part {

    local File="$1"
    local Format="$2"
    local Fallback="$3"
    local Timestamp

    Timestamp=$(Get_File_Birth "$File")

    if [ "$Timestamp" != '0' ] && [ -n "$Timestamp" ]; then
        date -d "@$Timestamp" "$Format" 2>/dev/null || printf '%s' "$Fallback"
    else
        printf '%s' "$Fallback"
    fi
}

function Get_MD5Sum {

    local Hash

    read -r Hash _ < <(md5sum -b -- "$1")

    printf '%s' "$Hash"
}

function Get_SHA256Sum {

    local Hash

    read -r Hash _ < <(sha256sum -b -- "$1")

    printf '%s' "$Hash"
}

function Get_Hash {

    local Method="$1"
    local File="$2"

    case "$Method" in
        md5)
            Get_MD5Sum "$File"
            ;;
        sha256)
            Get_SHA256Sum "$File"
            ;;
        *)
            printf '%s' ''
            ;;
    esac
}

function Get_MIME {
    file -b --mime-type -- "$1" 2>/dev/null
}

function Probe_Value {

    local File="$1"
    local Entries="$2"
    local StreamSpec="$3"
    local Value

    if [ -n "$StreamSpec" ]; then
        Value=$(
            timeout 10s ffprobe \
                -v error \
                -select_streams "$StreamSpec" \
                -show_entries "$Entries" \
                -of default=noprint_wrappers=1:nokey=1 \
                -- "$File" 2>/dev/null |
            head -n 1
        )
    else
        Value=$(
            timeout 10s ffprobe \
                -v error \
                -show_entries "$Entries" \
                -of default=noprint_wrappers=1:nokey=1 \
                -- "$File" 2>/dev/null |
            head -n 1
        )
    fi

    Value=$(Trim "$Value")

    printf '%s' "$Value"
}

function Probe_Tag {

    local File="$1"
    local Tag="$2"
    local Scope="${3:-format}"

    case "$Scope" in
        format)
            Probe_Value "$File" "format_tags=$Tag" ''
            ;;
        video)
            Probe_Value "$File" "stream_tags=$Tag" 'v:0'
            ;;
        audio)
            Probe_Value "$File" "stream_tags=$Tag" 'a:0'
            ;;
        *)
            printf '%s' ''
            ;;
    esac
}

# ============================================================
# METADATA HELPERS
# ============================================================

function Get_Media_WxH {

    local Result

    Result=$(
        timeout 10s ffprobe \
            -v error \
            -select_streams v:0 \
            -show_entries stream=width,height \
            -of csv=s=x:p=0 \
            -- "$1" 2>/dev/null
    )

    printf '%s' "${Result:-0x0}"
}

function Get_WxH_Format {

    if [[ ! "$1" =~ ^[0-9]+x[0-9]+$ ]]; then
        printf '%s' 'ZERO/UNKNOWN'
        return
    fi

    local W=${1%%x*}
    local H=${1##*x}
    local Max=$W
    local SizeClass='HUGE'
    local AspectClass='SQUARE'

    [ "$H" -gt "$W" ] && Max=$H

    if [ "$W" -eq 0 ] || [ "$H" -eq 0 ]; then
        SizeClass='ZERO'
    elif [ "$Max" -lt 512 ]; then
        SizeClass='SMALLER'
    elif [ "$Max" -lt 1024 ]; then
        SizeClass='SMALL'
    elif [ "$Max" -lt 2048 ]; then
        SizeClass='MEDIUM'
    elif [ "$Max" -lt 4096 ]; then
        SizeClass='BIG'
    elif [ "$Max" -lt 8096 ]; then
        SizeClass='BIGGER'
    fi

    if [ "$W" -gt "$H" ]; then
        AspectClass='WIDE'
    elif [ "$W" -lt "$H" ]; then
        AspectClass='HIGH'
    fi

    printf '%s/%s' "$SizeClass" "$AspectClass"
}

function Format_File_Size_Value {

    local Bytes="$1"
    local Mode="$2"
    local Div=1000
    local UnitIndex=0
    local Value="$Bytes"
    local Units

    case "$Mode" in
        size)
            Units=('B' 'KB' 'MB' 'GB' 'TB' 'PB')
            ;;
        size+format)
            Div=1024
            Units=('B' 'KiB' 'MiB' 'GiB' 'TiB' 'PiB')
            ;;
        format|format+size)
            Units=('BYTE' 'KILO' 'MEGA' 'GIGA' 'TERA' 'PETA')
            ;;
    esac

    while [ "$Value" -ge "$Div" ] && [ "$UnitIndex" -lt 5 ]; do
        Value=$((Value / Div))
        ((UnitIndex++))
    done

    case "$Mode" in
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
}

function Get_Doc_Title {

    local Line
    local Title=''

    while IFS= read -r Line; do
        [[ "$Line" == *'/Title'* ]] || continue
        Title=${Line#*(}
        Title=${Title%)*}
        break
    done < <(grep -a -m 1 '/Title' -- "$1" 2>/dev/null)

    if [ -z "$Title" ]; then
        Get_File_Name "$1"
    else
        Sanitize_File_Text "$Title"
    fi
}

function Get_Image_Meta {

    local Model

    Model=$(
        timeout 5s ffprobe \
            -v error \
            -show_entries format_tags=make,model \
            -of default=noprint_wrappers=1:nokey=1 \
            -- "$1" 2>/dev/null
    )

    Model=${Model//$'\n'/ }
    Model=$(Trim "$Model")

    if [ -z "$Model" ]; then
        Get_File_Name "$1"
    else
        Sanitize_File_Text "$Model"
    fi
}

function Get_Audio_Info {

    local Info

    Info=$(
        timeout 5s ffprobe \
            -v error \
            -show_entries format_tags=artist,title \
            -of default=noprint_wrappers=1:nokey=1 \
            -- "$1" 2>/dev/null
    )

    Info=${Info//$'\n'/-}
    Info=${Info%-}
    Info=$(Trim "$Info")

    if [ -z "$Info" ]; then
        Get_File_Name "$1"
    else
        Sanitize_File_Text "$Info"
    fi
}

function Get_Video_Title {

    local Title

    Title=$(
        timeout 10s ffprobe \
            -v error \
            -show_entries format_tags=title \
            -of default=noprint_wrappers=1:nokey=1 \
            -- "$1" 2>/dev/null
    )

    Title=$(Trim "$Title")

    if [ -z "$Title" ]; then
        Get_File_Name "$1"
    else
        Sanitize_File_Text "$Title"
    fi
}

# ============================================================
# METADATA CACHE
# ============================================================

function Build_Metadata {

    FILE_PATH="$1"
    FILE_NAME=$(Get_File_Name "$FILE_PATH")
    FILE_EXT=$(Get_File_Ext "$FILE_PATH")
    FILE_SIZE=$(Get_File_Size "$FILE_PATH")

    FILE_MIME=$(Get_MIME "$FILE_PATH")
    FILE_MIME_MAIN=${FILE_MIME%/*}
    FILE_MIME_SUB=${FILE_MIME#*/}

    FILE_WXH=''
    FILE_FORMAT=''

    FILE_DURATION=$(Probe_Value "$FILE_PATH" 'format=duration' '')
    FILE_DURATION_HMS=$(Format_Duration_HMS "$FILE_DURATION")
    FILE_FORMAT_NAME=$(Probe_Value "$FILE_PATH" 'format=format_name' '')
    FILE_FORMAT_LONG=$(Probe_Value "$FILE_PATH" 'format=format_long_name' '')
    FILE_BITRATE=$(Probe_Value "$FILE_PATH" 'format=bit_rate' '')
    FILE_BITRATE_LABEL=$(Format_Bitrate "$FILE_BITRATE")

    FILE_VCODEC=$(Probe_Value "$FILE_PATH" 'stream=codec_name' 'v:0')
    FILE_VCODEC_LONG=$(Probe_Value "$FILE_PATH" 'stream=codec_long_name' 'v:0')
    FILE_VPROFILE=$(Probe_Value "$FILE_PATH" 'stream=profile' 'v:0')
    FILE_PIXFMT=$(Probe_Value "$FILE_PATH" 'stream=pix_fmt' 'v:0')
    FILE_FPS=$(Probe_Value "$FILE_PATH" 'stream=r_frame_rate' 'v:0')

    FILE_ACODEC=$(Probe_Value "$FILE_PATH" 'stream=codec_name' 'a:0')
    FILE_ACODEC_LONG=$(Probe_Value "$FILE_PATH" 'stream=codec_long_name' 'a:0')
    FILE_CHANNELS=$(Probe_Value "$FILE_PATH" 'stream=channels' 'a:0')
    FILE_SAMPLE_RATE=$(Probe_Value "$FILE_PATH" 'stream=sample_rate' 'a:0')

    FILE_TAG_TITLE=$(Probe_Tag "$FILE_PATH" 'title' 'format')
    FILE_TAG_ARTIST=$(Probe_Tag "$FILE_PATH" 'artist' 'format')
    FILE_TAG_ALBUM=$(Probe_Tag "$FILE_PATH" 'album' 'format')
    FILE_TAG_DATE=$(First_Non_Empty \
        "$(Probe_Tag "$FILE_PATH" 'date' 'format')" \
        "$(Probe_Tag "$FILE_PATH" 'creation_time' 'format')")
    FILE_TAG_GENRE=$(Probe_Tag "$FILE_PATH" 'genre' 'format')
    FILE_TAG_TRACK=$(Probe_Tag "$FILE_PATH" 'track' 'format')

    if [[ "$FILE_MIME_MAIN" == 'image' || "$FILE_MIME_MAIN" == 'video' ]]; then
        FILE_WXH=$(Get_Media_WxH "$FILE_PATH")
        FILE_FORMAT=$(Get_WxH_Format "$FILE_WXH")
    fi
}

# ============================================================
# RULE RESOLUTION
# ============================================================

function Resolve_Path_Segment {

    local Req="${1,,}"

    case "$Req" in
        year)
            Get_Date_Part "$FILE_PATH" '+%Y' '0000'
            ;;
        month)
            Get_Date_Part "$FILE_PATH" '+%m' '00'
            ;;
        day)
            Get_Date_Part "$FILE_PATH" '+%d' '00'
            ;;
        created)
            Get_File_Creation_Time "$FILE_PATH"
            ;;
        modified)
            Get_File_Modification_Time "$FILE_PATH"
            ;;
        accessed)
            Get_File_Access_Time "$FILE_PATH"
            ;;
        extension)
            printf '%s' "${FILE_EXT^^}"
            ;;
        mime|mime/main/sub)
            printf '%s' "${FILE_MIME^^}"
            ;;
        mime-main)
            printf '%s' "${FILE_MIME_MAIN^^}"
            ;;
        mime-sub)
            printf '%s' "${FILE_MIME_SUB^^}"
            ;;
        size)
            if [[ "$FILE_MIME_MAIN" == 'image' || "$FILE_MIME_MAIN" == 'video' ]]; then
                printf '%s' "$FILE_WXH"
            else
                Format_File_Size_Value "$FILE_SIZE" 'size'
            fi
            ;;
        format)
            if [[ "$FILE_MIME_MAIN" == 'image' || "$FILE_MIME_MAIN" == 'video' ]]; then
                printf '%s' "$FILE_FORMAT"
            else
                Format_File_Size_Value "$FILE_SIZE" 'format'
            fi
            ;;
        size+format)
            if [[ "$FILE_MIME_MAIN" == 'image' || "$FILE_MIME_MAIN" == 'video' ]]; then
                printf '%s/%s' "$FILE_WXH" "$FILE_FORMAT"
            else
                Format_File_Size_Value "$FILE_SIZE" 'size+format'
            fi
            ;;
        format+size)
            if [[ "$FILE_MIME_MAIN" == 'image' || "$FILE_MIME_MAIN" == 'video' ]]; then
                printf '%s/%s' "$FILE_FORMAT" "$FILE_WXH"
            else
                Format_File_Size_Value "$FILE_SIZE" 'format+size'
            fi
            ;;
        md5)
            Get_MD5Sum "$FILE_PATH"
            ;;
        sha256sum)
            Get_SHA256Sum "$FILE_PATH"
            ;;
        sha1sum|sha224sum|sha384sum|sha512sum)
            if command -v "$Req" &>/dev/null; then
                local Hash
                read -r Hash _ < <("$Req" -b -- "$FILE_PATH")
                printf '%s' "$Hash"
            else
                printf '%s' 'HASH_TOOL_MISSING'
            fi
            ;;
        random)
            printf '%s' "${RANDOM}${RANDOM}"
            ;;
        *)
            printf '%s' "$1"
            ;;
    esac
}

function Is_Dynamic_Value {

    local Value="${1,,}"

    case "$Value" in
        year|month|day|created|modified|accessed|extension|mime|mime/main/sub|mime-main|mime-sub|size|format|size+format|format+size|md5|sha256sum|sha1sum|sha224sum|sha384sum|sha512sum|random)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function Resolve_Dynamic_Chain {

    local Expr="$1"
    local Context="${2:-path}"
    local Result=''
    local Part
    local Value

    Expr=$(Trim "$Expr")

    IFS='+' read -ra PARTS <<< "$Expr"

    for Part in "${PARTS[@]}"; do
        Part=$(Trim "$Part")

        if ! Is_Dynamic_Value "$Part"; then
            printf '%s' "INVALID_VALUE_$Part"
            return
        fi

        Value=$(Resolve_Path_Segment "$Part")

        case "$Context" in
            path|name)
                Value=$(Slugify_Text "$Value")
                ;;
            extension)
                Value=$(Trim "$Value")
                ;;
        esac

        [ -z "$Value" ] && continue

        if [ -z "$Result" ]; then
            Result="$Value"
        else
            Result="${Result}_${Value}"
        fi
    done

    printf '%s' "$Result"
}

function Resolve_Flexible_Option {

    local Expr="$1"
    local Context="${2:-path}"
    local Result=''
    local Segment
    local SegmentResult

    Expr=$(Trim "$Expr")

    [ -z "$Expr" ] && {
        printf '%s' ''
        return
    }

    IFS='/' read -ra SEGMENTS <<< "$Expr"

    for Segment in "${SEGMENTS[@]}"; do
        Segment=$(Trim "$Segment")
        SegmentResult=$(Resolve_Dynamic_Chain "$Segment" "$Context")

        case "$Context" in
            path)
                SegmentResult=$(Normalize_Path_Text "$SegmentResult")
                ;;
            name)
                SegmentResult=$(Slugify_Text "$SegmentResult")
                ;;
            extension)
                SegmentResult=$(Trim "$SegmentResult")
                ;;
        esac

        [ -z "$SegmentResult" ] && continue

        if [ -z "$Result" ]; then
            Result="$SegmentResult"
        else
            case "$Context" in
                path)
                    Result="$Result/$SegmentResult"
                    ;;
                name|extension)
                    Result="${Result}_${SegmentResult}"
                    ;;
            esac
        fi
    done

    case "$Context" in
        path)
            Normalize_Path_Text "$Result"
            ;;
        name)
            Slugify_Text "$Result"
            ;;
        extension)
            printf '%s' "$Result"
            ;;
    esac
}

function Resolve_Template {

    local Template="$1"
    local Result="$Template"
    local Token
    local Expr
    local Value

    if [[ "$Result" != *'{'* ]]; then
        Resolve_Flexible_Option "$Result"
        return
    fi

    while [[ "$Result" =~ \{([^{}]+)\} ]]; do
        Token="${BASH_REMATCH[0]}"
        Expr="${BASH_REMATCH[1]}"
        Value=$(Resolve_Flexible_Option "$Expr")
        Result=${Result//"$Token"/$Value}
    done

    Normalize_Path_Text "$Result"
}

function Resolve_Title_Name {

    case "${FILE_MIME_MAIN,,}" in
        application)
            Get_Doc_Title "$FILE_PATH"
            ;;
        image)
            Get_Image_Meta "$FILE_PATH"
            ;;
        audio)
            Get_Audio_Info "$FILE_PATH"
            ;;
        video)
            Get_Video_Title "$FILE_PATH"
            ;;
        *)
            Get_File_Name "$FILE_PATH"
            ;;
    esac
}

# ============================================================
# VERIFIED TRANSPORT
# ============================================================

function Sync_Target {

    local Target="$1"

    sync -f -- "$Target" 2>/dev/null || sync
}

function Verify_File {

    local Source="$1"
    local Target="$2"
    local SourceSize
    local TargetSize
    local SourceHash
    local TargetHash

    case "$CFG_PROBE" in
        none)
            return 0
            ;;
        size|md5|sha256)
            ;;
        *)
            Print_Error "Invalid probe mode: $CFG_PROBE"
            return 1
            ;;
    esac

    SourceSize=$(Get_File_Size "$Source")
    TargetSize=$(Get_File_Size "$Target")

    if [ "$SourceSize" != "$TargetSize" ]; then
        Print_Error "Verify failed. Size mismatch: $Source"
        return 1
    fi

    [ "$CFG_PROBE" = 'size' ] && {
        ((COUNT_VERIFIED++))
        Print_Success "Verify OK using size: $Source"
        return 0
    }

    Sync_Target "$Target"

    SourceHash=$(Get_Hash "$CFG_PROBE" "$Source")
    TargetHash=$(Get_Hash "$CFG_PROBE" "$Target")

    if [ -z "$SourceHash" ] || [ "$SourceHash" != "$TargetHash" ]; then
        Print_Error "Verify failed. ${CFG_PROBE^^} mismatch: $Source"
        return 1
    fi

    ((COUNT_VERIFIED++))
    Print_Success "Verify OK using ${CFG_PROBE^^}: $Source"
    return 0
}

function Copy_File {

    local Source="$1"
    local Target="$2"

    cp -f -- "$Source" "$Target"
}

function Safe_Move {

    local Source="$1"
    local Target="$2"

    Copy_File "$Source" "$Target" || return 1

    if [ "$CFG_PROBE" != 'none' ]; then
        Verify_File "$Source" "$Target" || {
            rm -f -- "$Target"
            return 1
        }
    fi

    rm -f -- "$Source"
}

# ============================================================
# EMPTY SOURCE DIRECTORY CLEANUP
# ============================================================

function Is_Safe_Source_Directory_To_Remove {

    local Dir="$1"
    local RealDir
    local RealSource
    local RealTarget

    [ -z "$Dir" ] && return 1
    [ "$Dir" = '/' ] && return 1
    [ "$Dir" = '.' ] && return 1
    [ "$Dir" = '..' ] && return 1

    RealDir=$(Get_Realpath_Existing "$Dir")
    RealSource=$(Get_Realpath_Existing "$CFG_SOURCE")
    RealTarget=$(Get_Realpath_Existing "$CFG_TARGET")

    [ -z "$RealDir" ] && return 1
    [ "$RealDir" = "$RealTarget" ] && return 1
    [[ "$RealTarget" == "$RealDir"/* ]] && return 1
    [[ "$RealDir" != "$RealSource" && "$RealDir" != "$RealSource"/* ]] && return 1

    return 0
}

function Remove_Empty_Source_Directory {

    local Dir="$1"

    [ "$CFG_MODE" != 'move' ] && return 0
    Is_Safe_Source_Directory_To_Remove "$Dir" || return 0

    if rmdir -- "$Dir" 2>/dev/null; then
        ((COUNT_CLEANED_DIRS++))
        Print_Success "Removed empty source directory: $Dir"
    fi
}

# ============================================================
# TARGET SAFETY
# ============================================================

function Is_Target_Inside_Source {

    local SourceReal
    local TargetReal

    SourceReal=$(Get_Realpath_Existing "$CFG_SOURCE")
    TargetReal=$(Get_Realpath_Existing "$CFG_TARGET")

    [ -z "$SourceReal" ] && return 1
    [ -z "$TargetReal" ] && return 1

    [[ "$TargetReal" == "$SourceReal" || "$TargetReal" == "$SourceReal"/* ]]
}

function Validate_Target_Safety {

    [ -z "$CFG_SOURCE" ] && return 0
    [ "$CFG_RECURSIVE" != 'yes' ] && return 0

    if Is_Target_Inside_Source; then
        Print_Error "Target directory is inside the source directory. This would cause recursive self-processing."
        Print_Error "Source: $CFG_SOURCE"
        Print_Error "Target: $CFG_TARGET"
        exit 40
    fi
}

# ============================================================
# EXECUTION
# ============================================================

function Execute_Action {

    local Source="$1"
    local Target="$2"
    local TargetDir

    TargetDir=$(dirname -- "$Target")

    case "$CFG_MODE" in
        dummy)
            Print_Warning "Dry run: $Source -> $Target"
            ;;
        copy)
            mkdir -p -- "$TargetDir"
            Print_Info "Copy: $Source -> $Target"
            if Copy_File "$Source" "$Target"; then
                ((COUNT_COPIED++))
                if [ "$CFG_PROBE" != 'none' ]; then
                    Verify_File "$Source" "$Target" || {
                        ((COUNT_FAILED++))
                        return 1
                    }
                fi
            else
                ((COUNT_FAILED++))
                return 1
            fi
            ;;
        move)
            mkdir -p -- "$TargetDir"
            Print_Warning "Move: $Source -> $Target"
            if Safe_Move "$Source" "$Target"; then
                ((COUNT_MOVED++))
            else
                ((COUNT_FAILED++))
                return 1
            fi
            ;;
        remove)
            Print_Error "Remove: $Source"
            if rm -f -- "$Source"; then
                ((COUNT_REMOVED++))
            else
                ((COUNT_FAILED++))
                return 1
            fi
            ;;
        *)
            Print_Error "Unknown mode: $CFG_MODE"
            ((COUNT_FAILED++))
            return 1
            ;;
    esac
}

# ============================================================
# FILE PROCESSING
# ============================================================

function Build_Target_Path {

    local TargetDir="$CFG_TARGET"
    local MainDir=''
    local SubDir=''
    local Name
    local Ext

    [ -n "$CFG_DIRS" ] && MainDir=$(Resolve_Flexible_Option "$CFG_DIRS" 'path')
    [ -n "$CFG_SUBDIRS" ] && SubDir=$(Resolve_Flexible_Option "$CFG_SUBDIRS" 'path')

    [ -n "$MainDir" ] && TargetDir="$TargetDir/$MainDir"
    [ -n "$SubDir" ] && TargetDir="$TargetDir/$SubDir"

    if [ "$CFG_TITLE" = 'yes' ]; then
        Name=$(Resolve_Title_Name)
    else
        Name="$FILE_NAME"
    fi

    [ -n "$CFG_RENAME" ] && Name=$(Resolve_Flexible_Option "$CFG_RENAME" 'name')
    Name=$(Slugify_Text "$Name")
    [ -z "$Name" ] && Name="$FILE_NAME"

    Ext="$FILE_EXT"

    if [ -n "$CFG_EXTENSION" ]; then
        Ext=$(Resolve_Flexible_Option "$CFG_EXTENSION" 'extension')
        Ext=${Ext,,}
        Ext=${Ext//\//.}
        Ext=${Ext// /_}
        Ext=${Ext//_/.}
        Ext=${Ext#.}
    fi

    if [ -n "$Ext" ]; then
        FINAL_PATH="$TargetDir/$Name.$Ext"
    else
        FINAL_PATH="$TargetDir/$Name"
    fi

    if [ "$CFG_REPLACE" != 'yes' ]; then
        local Count=1
        local BasePath="$TargetDir/$Name"

        while [ -e "$FINAL_PATH" ]; do
            if [ -n "$Ext" ]; then
                FINAL_PATH="$BasePath-($Count).$Ext"
            else
                FINAL_PATH="$BasePath-($Count)"
            fi
            ((Count++))
        done
    fi
}

function Process_File {

    local Item="$1"

    Build_Metadata "$Item"

    if [ -n "$CFG_TYPE" ]; then
        if [[ "${FILE_MIME,,}" != *"${CFG_TYPE,,}"* ]]; then
            ((COUNT_SKIPPED++))
            return 0
        fi
    fi

    Build_Target_Path

    ((COUNT_PROCESSED++))

    Print_Label 'File' "$Item"
    Print_Label 'Type' "$FILE_MIME"
    Print_Label 'Target' "$FINAL_PATH"

    Execute_Action "$Item" "$FINAL_PATH"

    [ -n "$CFG_PAUSE" ] && sleep "$CFG_PAUSE"
}

# ============================================================
# DIRECTORY PROCESSING
# ============================================================

function Process_Path {

    local Item="$1"

    if [[ ! -e "$Item" ]]; then
        ((COUNT_SKIPPED++))
        Print_Warning "Skipped missing path: $Item"
        return 0
    fi

    if [[ -L "$Item" ]]; then
        ((COUNT_SKIPPED++))
        Print_Warning "Skipped symbolic link: $Item"
        return 0
    fi

    if [[ -f "$Item" ]]; then
        Process_File "$Item"
        return $?
    fi

    if [[ -d "$Item" ]]; then
        if [ "$CFG_RECURSIVE" != 'yes' ]; then
            ((COUNT_SKIPPED++))
            Print_Warning "Skipped directory because --recursive is not enabled: $Item"
            return 0
        fi

        local Child
        local FoundChild='no'

        for Child in "$Item"/*; do
            [ -e "$Child" ] || continue
            FoundChild='yes'
            Process_Path "$Child"
        done

        [ "$FoundChild" = 'no' ] && Print_Info "Empty source directory found: $Item"

        Remove_Empty_Source_Directory "$Item"
    fi
}

# ============================================================
# ARGUMENT PARSER
# ============================================================

function Parse_Probe_Value {

    local Value="$1"

    if [ -z "$Value" ]; then
        printf '%s' 'md5'
        return
    fi

    case "${Value,,}" in
        yes|true|on)
            printf '%s' 'md5'
            ;;
        no|false|off|none)
            printf '%s' 'none'
            ;;
        size|md5|sha256)
            printf '%s' "${Value,,}"
            ;;
        *)
            printf '%s' "${Value,,}"
            ;;
    esac
}

function Parse_Arguments {

    while [ $# -gt 0 ]; do
        case "${1,,}" in
            --mode=*)
                CFG_MODE=$(Normalize_Option_Value "${1#*=}")
                ;;
            --recursive)
                CFG_RECURSIVE='yes'
                ;;
            --replace)
                CFG_REPLACE='yes'
                ;;
            --probe)
                CFG_PROBE='md5'
                ;;
            --probe=*)
                CFG_PROBE=$(Parse_Probe_Value "${1#*=}")
                ;;
            --title)
                CFG_TITLE='yes'
                ;;
            --type=*)
                CFG_TYPE=$(Normalize_Option_Value "${1#*=}")
                ;;
            --pause=*)
                CFG_PAUSE=$(Trim "${1#*=}")
                ;;
            --dirs=*)
                CFG_DIRS=$(Trim "${1#*=}")
                ;;
            --subdirs=*)
                CFG_SUBDIRS=$(Trim "${1#*=}")
                ;;
            --rename=*)
                CFG_RENAME=$(Trim "${1#*=}")
                ;;
            --extension=*)
                CFG_EXTENSION=$(Trim "${1#*=}")
                ;;
            --source=*)
                CFG_SOURCE=$(Trim "${1#*=}")
                ;;
            --target=*)
                CFG_TARGET=$(Trim "${1#*=}")
                ;;
            --log=*)
                CFG_LOG=$(Trim "${1#*=}")
                ;;
            --self-test)
                CFG_SELF_TEST='yes'
                ;;
            --help|-h)
                Show_Usage
                exit 0
                ;;
            *)
                INPUTS+=("$1")
                ;;
        esac

        shift
    done
}

function Validate_Config {

    case "$CFG_MODE" in
        dummy|copy|move|remove)
            ;;
        *)
            Print_Error "Invalid mode: $CFG_MODE"
            Print_Line 'Allowed modes: dummy, copy, move, remove'
            exit 20
            ;;
    esac

    case "$CFG_PROBE" in
        none|size|md5|sha256)
            ;;
        *)
            Print_Error "Invalid probe mode: $CFG_PROBE"
            Print_Line 'Allowed probe modes: none, size, md5, sha256'
            exit 21
            ;;
    esac

    if [ "$CFG_PROBE" != 'none' ] && [ "$CFG_MODE" = 'remove' ]; then
        Print_Warning '--probe is ignored with --mode=remove'
    fi

    if [ -n "$CFG_SOURCE" ]; then
        INPUTS+=("$CFG_SOURCE")
    fi

    CFG_TARGET=$(Get_Realpath_Existing "$CFG_TARGET")

    if [ -z "$CFG_TARGET" ]; then
        Print_Error 'Target path could not be resolved.'
        exit 22
    fi

    Validate_Target_Safety
}

# ============================================================
# SUMMARY
# ============================================================

function Show_Summary {

    Draw_Line '-'
    Print_Label 'Processed files' "$COUNT_PROCESSED"
    Print_Label 'Copied files' "$COUNT_COPIED"
    Print_Label 'Moved files' "$COUNT_MOVED"
    Print_Label 'Removed files' "$COUNT_REMOVED"
    Print_Label 'Skipped items' "$COUNT_SKIPPED"
    Print_Label 'Failed actions' "$COUNT_FAILED"
    Print_Label 'Verified files' "$COUNT_VERIFIED"
    Print_Label 'Cleaned directories' "$COUNT_CLEANED_DIRS"
    Draw_Line '-'
}

# ============================================================
# SELF TEST
# ============================================================

function Run_Self_Test {

    local TestRoot
    local SourceDir
    local TargetDir

    TestRoot=$(mktemp -d)
    SourceDir="$TestRoot/source"
    TargetDir="$TestRoot/target"

    mkdir -p "$SourceDir/empty" "$SourceDir/nested"

    printf 'alpha\n' > "$SourceDir/a.txt"
    printf 'beta\n' > "$SourceDir/nested/b.txt"

    Print_Info "Self-test root: $TestRoot"

    CFG_MODE='move'
    CFG_RECURSIVE='yes'
    CFG_PROBE='md5'
    CFG_SOURCE="$SourceDir"
    CFG_TARGET="$TargetDir"
    CFG_DIRS='extension'
    CFG_SUBDIRS=''
    CFG_RENAME=''
    CFG_EXTENSION=''
    CFG_TYPE=''
    CFG_REPLACE='no'

    Validate_Target_Safety
    Process_Path "$SourceDir"
    Show_Summary

    if [ -e "$SourceDir" ]; then
        Print_Error 'Self-test failed. Source directory still exists.'
        Print_Info "Inspect manually: $TestRoot"
        return 1
    fi

    if [ ! -f "$TargetDir/TXT/a.txt" ] || [ ! -f "$TargetDir/TXT/b.txt" ]; then
        Print_Error 'Self-test failed. Expected files are missing from target.'
        Print_Info "Inspect manually: $TestRoot"
        return 1
    fi

    rm -rf -- "$TestRoot"
    Print_Success 'Self-test completed successfully.'
}

# ============================================================
# USAGE
# ============================================================

function Show_Usage {

    Draw_Line '='
    Print_Line 'Sort.sh'
    Print_Line 'Metadata-driven file organizer with safe transport modes'
    Draw_Line '='

    cat << 'EOF'

SYNTAX:
    Sort.sh [OPTIONS] [FILES OR DIRECTORIES]

SOURCE AND TARGET:
    --source=DIR
        Source directory to process.
        This can be used instead of passing paths at the end.

    --target=DIR
        Base output directory.
        All generated folders and files are placed under this directory.
        Default: current directory

MODES:
    --mode=dummy
        Show what would happen. No files are changed.

    --mode=copy
        Copy files to the calculated target path.

    --mode=move
        Copy files to the calculated target path, then remove the source.
        With --probe, source removal happens only after verification succeeds.

    --mode=remove
        Remove source files.

SAFETY:
    --probe
        Same as --probe=md5.

    --probe=size
        Verify copied files by comparing file size only.
        Fastest, but least strict.

    --probe=md5
        Verify copied files by comparing size and MD5.
        Good balance for storage migration.

    --probe=sha256
        Verify copied files by comparing size and SHA256.
        Strongest, but slower.

    --replace
        Allow overwriting existing target files.
        Without this option, duplicate names become name-(1), name-(2), etc.

    --recursive
        Process directories recursively.
        In move mode, empty source directories are removed after processing.

    --log=FILE
        Write a plain-text log without terminal color codes.

    --self-test
        Run a small built-in test using temporary folders.

FILTERS:
    --type=VALUE
        Process only files whose MIME type contains VALUE.

        Examples:
            --type=image
            --type=video
            --type=audio
            --type=application/pdf

NAMING:
    --title
        Try to rename files using metadata.

        application files: document title
        image files:       camera make and model
        audio files:       artist and title
        video files:       internal title
        other files:       original filename

    --rename=VALUE
        Override the filename using a dynamic value.

    --extension=VALUE
        Override the extension using a dynamic value.

DIRECTORIES:
    --dirs=VALUE
        Main target directory below --target.

    --subdirs=VALUE
        Secondary target directory below --dirs.

DYNAMIC VALUES:
    year
    month
    day
    year+month
    year+month+day
    created
    modified
    accessed

    extension
    mime
    mime-main
    mime-sub

    size
    format
    size+format
    format+size

    md5
    sha256sum
    sha1sum
    sha224sum
    sha384sum
    sha512sum
    random

EXAMPLES:
    Sort.sh --mode=dummy --source=./Downloads --target=./Sorted --dirs=year+month --recursive

    Sort.sh --mode=copy --probe=md5 --source=./Media --target=/media/Backup --dirs=mime-main --subdirs=extension --recursive

    Sort.sh --mode=move --probe=sha256 --source=/media/CameraCard --target=/media/Archive --recursive --dirs=year+month

    Sort.sh --mode=copy --rename=sha256sum --extension=jpg --target=./Images *.jpeg

    Sort.sh --mode=move --type=image --dirs=year --subdirs=format+size --target=./Sorted ./Pictures/*

EOF

    Draw_Line '='
}

# ============================================================
# MAIN
# ============================================================

Check_Requirements

if [ $# -eq 0 ]; then
    Show_Usage
    exit 0
fi

Parse_Arguments "$@"

if [ "$CFG_SELF_TEST" = 'yes' ]; then
    Run_Self_Test
    exit $?
fi

Validate_Config

if [ ${#INPUTS[@]} -eq 0 ]; then
    Print_Error 'No input files or directories provided.'
    exit 30
fi

Print_Label 'Mode' "$CFG_MODE"
Print_Label 'Probe' "$CFG_PROBE"
Print_Label 'Target' "$CFG_TARGET"
[ -n "$CFG_SOURCE" ] && Print_Label 'Source' "$CFG_SOURCE"
[ -n "$CFG_LOG" ] && Print_Label 'Log' "$CFG_LOG"

for Item in "${INPUTS[@]}"; do
    Process_Path "$Item"
done

Show_Summary

if [ "$COUNT_FAILED" -gt 0 ]; then
    Print_Error 'Completed with failures.'
    exit 50
fi

Print_Success 'Complete. Finished processing.'
exit 0
