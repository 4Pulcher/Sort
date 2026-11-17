#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : imagemagick.sh                                                    #
# Version : 2.1                                                               #
# Desc    : Complete image toolkit - ImageMagick identify / magick            #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of image tools built on ImageMagick: dimension,
# format, color, depth, quality, DPI, orientation, camera and GPS getters,
# plus resize / thumbnail / convert / rotate / grayscale / strip actions.
# Every function takes a path as its first argument, prints its result on
# stdout and returns non-zero on failure. When the deps module is loaded,
# a missing ImageMagick triggers an install proposal (see ../deps).

# ---------------------------------------------------------------------------
# Internal helper: identify with a magick-identify fallback (returns 127 when
# ImageMagick is absent). _IM_Identify <format-string> <file>
# ---------------------------------------------------------------------------

_IM_Identify() {
	local Format=$1
	local File=$2
	local Out

	if command -v identify >/dev/null; then
		Out=$(timeout 10s identify -ping -format "$Format" -- "$File" 2>/dev/null)
	elif command -v magick >/dev/null; then
		Out=$(timeout 10s magick identify -ping -format "$Format" -- "$File" 2>/dev/null)
	elif declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure identify; then
		# ImageMagick was just installed - retry the read.
		Out=$(timeout 10s identify -ping -format "$Format" -- "$File" 2>/dev/null)
	else
		return 127
	fi

	[ -n "$Out" ] || return 1
	printf '%s' "$Out"
}

# ---------------------------------------------------------------------------
# Internal helper: pick magick or convert for image actions.
# _IM_Tool <args...>  (runs the found tool with the given arguments)
# ---------------------------------------------------------------------------

_IM_Tool() {
	if command -v magick >/dev/null; then
		timeout 120s magick "$@" 2>/dev/null
	elif command -v convert >/dev/null; then
		timeout 120s convert "$@" 2>/dev/null
	elif declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure magick; then
		# ImageMagick was just installed - retry the action.
		timeout 120s magick "$@" 2>/dev/null
	else
		return 127
	fi
}

# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------

Get_Image_WxH() {
	local File=$1
	local Resolution

	# First use without ImageMagick: propose the install, then fall back to 0x0.
	command -v identify >/dev/null || command -v magick >/dev/null || {
		declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure identify
	}

	Resolution=$(
		identify -ping -format '%wx%h\n' -- "$File" 2>/dev/null |
			head -n 1 |
			tr -d '\r\n '
	)

	printf '%s' "${Resolution:-0x0}"
}

Get_Image_Width() {
	local File=$1
	local Width

	Width=$(_IM_Identify '%w' "$File") || return $?
	printf '%s' "$Width"
}

Get_Image_Height() {
	local File=$1
	local Height

	Height=$(_IM_Identify '%h' "$File") || return $?
	printf '%s' "$Height"
}

# ---------------------------------------------------------------------------
# Format, colors, depth, quality, DPI, orientation
# ---------------------------------------------------------------------------

Get_Image_Format() {
	local File=$1
	local Format

	Format=$(_IM_Identify '%m' "$File") || return $?
	printf '%s' "$Format"
}

Get_Image_Colors() {
	local File=$1
	local Colors

	Colors=$(_IM_Identify '%k' "$File") || return $?
	printf '%s' "$Colors"
}

Get_Image_Depth() {
	local File=$1
	local Depth

	Depth=$(_IM_Identify '%z' "$File") || return $?
	printf '%s' "$Depth"
}

Get_Image_Quality() {
	local File=$1
	local Quality

	Quality=$(_IM_Identify '%Q' "$File") || return $?
	printf '%s' "$Quality"
}

Get_Image_DPI() {
	local File=$1
	local X Y

	X=$(_IM_Identify '%x' "$File") || return $?
	Y=$(_IM_Identify '%y' "$File") || return $?
	printf '%sx%s' "${X%% *}" "${Y%% *}"
}

Get_Image_Orientation() {
	local File=$1
	local Orientation

	Orientation=$(_IM_Identify '%[orientation]' "$File") || return $?
	printf '%s' "$Orientation"
}

# ---------------------------------------------------------------------------
# Camera and GPS metadata (EXIF)
# ---------------------------------------------------------------------------

Get_Image_Camera() {
	local File=$1
	local Make Model

	Make=$(_IM_Identify '%[exif:Make]' "$File") || Make=''
	Model=$(_IM_Identify '%[exif:Model]' "$File") || Model=''

	[ -n "$Make" ] || [ -n "$Model" ] || return 1
	printf '%s %s' "$Make" "$Model"
}

Get_Image_GPS() {
	local File=$1
	local Lat Lon

	Lat=$(_IM_Identify '%[exif:GPSLatitude]' "$File") || Lat=''
	Lon=$(_IM_Identify '%[exif:GPSLongitude]' "$File") || Lon=''

	[ -n "$Lat" ] || [ -n "$Lon" ] || return 1
	printf '%s,%s' "$Lat" "$Lon"
}

# ---------------------------------------------------------------------------
# Capture date: EXIF original date, then ffprobe, then file birth time.
# Self-contained - does not depend on other function modules.
# ---------------------------------------------------------------------------

Get_Image_Meta() {
	local File=$1
	local Date

	[ -f "$File" ] || return 1

	Date=$(_IM_Identify '%[exif:DateTimeOriginal]' "$File" 2>/dev/null)

	if [ -z "$Date" ] && command -v ffprobe >/dev/null; then
		Date=$(
			timeout 5s ffprobe \
				-v error \
				-show_entries format_tags=date_time_original \
				-of default=noprint_wrappers=1:nokey=1 \
				-- "$File" 2>/dev/null
		)
	fi

	if [ -z "$Date" ] && command -v stat >/dev/null; then
		Date=$(stat -c '%w' -- "$File" 2>/dev/null)
		[ "$Date" = "-" ] && Date=''
	fi

	[ -n "$Date" ] || return 1
	printf '%s' "$Date"
}

# ---------------------------------------------------------------------------
# Validity predicate
# ---------------------------------------------------------------------------

Image_Is_Valid() {
	local File=$1

	[ -f "$File" ] || return 1
	_IM_Identify '%m' "$File" >/dev/null
}

# ---------------------------------------------------------------------------
# Size tier / aspect classifier (shared with the ffmpeg module)
# Input: "WxH" - Output: "LEVEL/ASPECT"
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Actions: resize, thumbnail, convert, rotate, grayscale, strip metadata
# ---------------------------------------------------------------------------

Image_Resize() {
	local In=$1
	local Size=$2
	local Out=$3

	[ -f "$In" ] && [ -n "$Size" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -resize "$Size" "$Out"
}

Image_Thumbnail() {
	local In=$1
	local Size=${2:-256x256}
	local Out=$3

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -thumbnail "$Size" "$Out"
}

Image_Convert() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" "$Out"
}

Image_Rotate() {
	local In=$1
	local Degrees=$2
	local Out=$3

	[ -f "$In" ] && [ -n "$Degrees" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -rotate "$Degrees" "$Out"
}

Image_Grayscale() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -colorspace Gray "$Out"
}

Image_Strip() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_IM_Tool "$In" -strip "$Out"
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
