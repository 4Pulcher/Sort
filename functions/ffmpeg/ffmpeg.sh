#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : ffmpeg.sh                                                         #
# Version : 2.1                                                               #
# Desc    : Complete media toolkit - ffmpeg / ffprobe                         #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of media tools built on ffmpeg/ffprobe: codecs,
# container, duration, bitrate, FPS, channels, sample rate, tag getters,
# validity checks, plus extract-audio / convert / thumbnail / strip actions.
# Every function takes a path as its first argument, prints its result on
# stdout and returns non-zero on failure. When the deps module is loaded,
# a missing ffmpeg/ffprobe triggers an install proposal (see ../deps).

# ---------------------------------------------------------------------------
# Internal helper: true when the tool exists - otherwise propose installing
# it through the deps module (when loaded) and report the outcome.
# _FF_Have <tool>
# ---------------------------------------------------------------------------

_FF_Have() {
	local Tool=$1

	command -v "$Tool" >/dev/null 2>&1 && return 0
	declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure "$Tool"
}

# Internal helper: raw ffprobe run. _FF_Run <select|''> <entries> <file>
_FF_Run() {
	local Select=$1
	local Entries=$2
	local File=$3
	local Args=()

	[[ -n "$Select" ]] && Args=(-select_streams "$Select")

	timeout 10s ffprobe \
		-v error \
		"${Args[@]}" \
		-show_entries "$Entries" \
		-of default=noprint_wrappers=1:nokey=1 \
		-- "$File" 2>/dev/null
}

# Internal helper: probe and fail cleanly on empty output.
# _Probe <entries> <file>
_Probe() {
	local Out

	_FF_Have ffprobe || return 127

	Out=$(_FF_Run '' "$1" "$2")
	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}

# Internal helper: probe one stream. _Probe_Stream <entries> <select> <file>
_Probe_Stream() {
	local Out

	_FF_Have ffprobe || return 127

	Out=$(_FF_Run "$2" "$1" "$3")
	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}

# ---------------------------------------------------------------------------
# Dimensions (kept from v1.0)
# ---------------------------------------------------------------------------

Get_Media_WxH() {
	local File=$1
	local Resolution

	# First use without ffprobe: propose the install, then fall back to 0x0.
	command -v ffprobe >/dev/null 2>&1 ||
		{ declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure ffprobe; }

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

	_Probe_Stream stream=codec_name v:0 "$File"
}

Get_Audio_Codec() {
	local File=$1

	_Probe_Stream stream=codec_name a:0 "$File"
}

Get_Container() {
	local File=$1

	_Probe format=format_name "$File"
}

Get_Duration() {
	local File=$1

	_Probe format=duration "$File"
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

	_Probe format=bit_rate "$File"
}

Get_FPS() {
	local File=$1
	local Fraction Num Den

	Fraction=$(_Probe_Stream stream=avg_frame_rate v:0 "$File") || return $?

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

	_Probe_Stream stream=channels a:0 "$File"
}

Get_Sample_Rate() {
	local File=$1

	_Probe_Stream stream=sample_rate a:0 "$File"
}

# ---------------------------------------------------------------------------
# Tag getters
# ---------------------------------------------------------------------------

Get_Media_Title() {
	local File=$1

	_Probe format_tags=title "$File"
}

Get_Media_Artist() {
	local File=$1

	_Probe format_tags=artist "$File"
}

Get_Media_Album() {
	local File=$1

	_Probe format_tags=album "$File"
}

Get_Media_Genre() {
	local File=$1

	_Probe format_tags=genre "$File"
}

Get_Media_Track() {
	local File=$1

	_Probe format_tags=track "$File"
}

Get_Media_Date() {
	local File=$1

	_Probe format_tags=date "$File"
}

# Print every "KEY=VALUE" format tag, one per line.
Get_Media_Tags() {
	local File=$1
	local Tags

	_FF_Have ffprobe || return 127

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
	_FF_Have ffprobe || return 127

	timeout 10s ffprobe -v error -- "$File" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Composite tag lines (kept from v1.0)
# ---------------------------------------------------------------------------

Get_Audio_Info() {
	local File=$1
	local Artist Album Title Info=""

	_FF_Have ffprobe || return 127

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

	_FF_Have ffprobe || return 127

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
	_FF_Have ffmpeg || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -vn -acodec copy -- "$Out" >/dev/null 2>&1
}

Media_Convert() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_FF_Have ffmpeg || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -- "$Out" >/dev/null 2>&1
}

Media_Thumbnail() {
	local Video=$1
	local Time=${2:-00:00:01}
	local Out=$3

	[ -f "$Video" ] && [ -n "$Out" ] || return 1
	_FF_Have ffmpeg || return 127

	timeout 60s ffmpeg -y -v error -ss "$Time" -i "$Video" -frames:v 1 -q:v 2 -- "$Out" >/dev/null 2>&1
}

Media_Strip_Metadata() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_FF_Have ffmpeg || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -map_metadata -1 -c copy -- "$Out" >/dev/null 2>&1
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
