#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : ffmpeg.sh                                                         #
# Version : 2.0                                                               #
# Desc    : Complete media toolkit - ffmpeg / ffprobe                         #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of media tools built on ffmpeg/ffprobe: codecs,
# container, duration, bitrate, FPS, channels, sample rate, tag getters,
# validity checks, plus extract-audio / convert / thumbnail / strip actions.
# Every function takes a path as its first argument, prints its result on
# stdout and returns non-zero on failure. No globals required.

# ---------------------------------------------------------------------------
# Internal helper: ffprobe a list of entries, print values one per line.
# Returns 127 when ffprobe is absent. _Probe <entries> <file>
# ---------------------------------------------------------------------------

_Probe() {
	local Entries=$1
	local File=$2
	local Out

	command -v ffprobe >/dev/null || return 127

	Out=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries "$Entries" \
			-of default=noprint_wrappers=1:nokey=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}

# ---------------------------------------------------------------------------
# Dimensions (kept from v1.0)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Codecs, container, duration, bitrate, FPS, channels, sample rate
# ---------------------------------------------------------------------------

Get_Video_Codec() {
	local File=$1
	local Codec

	Codec=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams v:0 \
			-show_entries stream=codec_name \
			-of default=noprint_wrappers=1:nokey=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Codec" ] || return 1
	printf '%s' "$Codec"
}

Get_Audio_Codec() {
	local File=$1
	local Codec

	Codec=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams a:0 \
			-show_entries stream=codec_name \
			-of default=noprint_wrappers=1:nokey=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Codec" ] || return 1
	printf '%s' "$Codec"
}

Get_Container() {
	local File=$1
	local Container

	Container=$(_Probe format=format_name "$File") || return $?
	printf '%s' "$Container"
}

Get_Duration() {
	local File=$1
	local Duration

	Duration=$(_Probe format=duration "$File") || return $?
	printf '%s' "$Duration"
}

Get_Duration_Human() {
	local File=$1
	local Seconds
	local H M S

	Seconds=$(_Probe format=duration "$File") || return $?
	# Keep only the integer part before converting.
	Seconds=${Seconds%%.*}

	H=$((Seconds / 3600))
	M=$(((Seconds % 3600) / 60))
	S=$((Seconds % 60))

	printf '%02d:%02d:%02d' "$H" "$M" "$S"
}

Get_Bitrate() {
	local File=$1
	local Bitrate

	Bitrate=$(_Probe format=bit_rate "$File") || return $?
	printf '%s' "$Bitrate"
}

Get_FPS() {
	local File=$1
	local Fraction Num Den

	Fraction=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams v:0 \
			-show_entries stream=avg_frame_rate \
			-of default=noprint_wrappers=1:nokey=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Fraction" ] || return 1

	# avg_frame_rate is a fraction like "30000/1001" - evaluate it safely.
	Num=${Fraction%%/*}
	Den=${Fraction##*/}
	if [[ "$Num" =~ ^[0-9]+$ ]] && [[ "$Den" =~ ^[0-9]+$ ]] && ((Den > 0)); then
		printf '%d.%d' $((Num / Den)) $(((Num % Den) * 10 / Den))
	else
		printf '%s' "$Fraction"
	fi
}

Get_Audio_Channels() {
	local File=$1
	local Channels

	Channels=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams a:0 \
			-show_entries stream=channels \
			-of default=noprint_wrappers=1:nokey=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Channels" ] || return 1
	printf '%s' "$Channels"
}

Get_Sample_Rate() {
	local File=$1
	local Rate

	Rate=$(
		timeout 10s ffprobe \
			-v error \
			-select_streams a:0 \
			-show_entries stream=sample_rate \
			-of default=noprint_wrappers=1:nokey=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Rate" ] || return 1
	printf '%s' "$Rate"
}

# ---------------------------------------------------------------------------
# Tag getters
# ---------------------------------------------------------------------------

Get_Media_Title() {
	local File=$1
	local Title

	Title=$(_Probe format_tags=title "$File") || return $?
	printf '%s' "$Title"
}

Get_Media_Artist() {
	local File=$1
	local Artist

	Artist=$(_Probe format_tags=artist "$File") || return $?
	printf '%s' "$Artist"
}

Get_Media_Album() {
	local File=$1
	local Album

	Album=$(_Probe format_tags=album "$File") || return $?
	printf '%s' "$Album"
}

Get_Media_Genre() {
	local File=$1
	local Genre

	Genre=$(_Probe format_tags=genre "$File") || return $?
	printf '%s' "$Genre"
}

Get_Media_Track() {
	local File=$1
	local Track

	Track=$(_Probe format_tags=track "$File") || return $?
	printf '%s' "$Track"
}

Get_Media_Date() {
	local File=$1
	local Date

	Date=$(_Probe format_tags=date "$File") || return $?
	printf '%s' "$Date"
}

# Print every "KEY=VALUE" format tag, one per line.
Get_Media_Tags() {
	local File=$1
	local Tags

	command -v ffprobe >/dev/null || return 127

	Tags=$(
		timeout 10s ffprobe \
			-v error \
			-show_entries format_tags \
			-of default=noprint_wrappers=1 \
			-- "$File" 2>/dev/null
	)

	[ -n "$Tags" ] || return 1
	printf '%s\n' "$Tags"
}

# ---------------------------------------------------------------------------
# Validity predicate
# ---------------------------------------------------------------------------

Media_Is_Valid() {
	local File=$1

	[ -f "$File" ] || return 1
	command -v ffprobe >/dev/null || return 127

	timeout 10s ffprobe -v error -- "$File" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Composite tag lines (kept from v1.0)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Actions: extract audio, convert, thumbnail, strip metadata
# ---------------------------------------------------------------------------

Media_Extract_Audio() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	command -v ffmpeg >/dev/null || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -vn -acodec copy -- "$Out" >/dev/null 2>&1
}

Media_Convert() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	command -v ffmpeg >/dev/null || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -- "$Out" >/dev/null 2>&1
}

Media_Thumbnail() {
	local Video=$1
	local Time=${2:-00:00:01}
	local Out=$3

	[ -f "$Video" ] && [ -n "$Out" ] || return 1
	command -v ffmpeg >/dev/null || return 127

	timeout 60s ffmpeg -y -v error -ss "$Time" -i "$Video" -frames:v 1 -q:v 2 -- "$Out" >/dev/null 2>&1
}

Media_Strip_Metadata() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	command -v ffmpeg >/dev/null || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -map_metadata -1 -c copy -- "$Out" >/dev/null 2>&1
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
