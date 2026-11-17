#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : exif.sh                                                           #
# Version : 2.1                                                               #
# Desc    : Complete EXIF toolkit - exiftool / ImageMagick fallback           #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of EXIF tools built on exiftool (with an
# ImageMagick identify fallback for common tags): generic tag access, full
# dumps, camera / lens / exposure / GPS getters, plus strip / set / copy
# actions. Every function prints its result on stdout and returns non-zero
# on failure. When the deps module is loaded, a missing exiftool triggers an
# install proposal (see ../deps). No globals required.

# ---------------------------------------------------------------------------
# Internal helper: read one EXIF tag. Tries exiftool first, then the
# ImageMagick exif: namespace. Returns 127 when no reader is available.
# _Exif_Read <Tag> <file>
# ---------------------------------------------------------------------------

_Exif_Read() {
	local Tag=$1
	local File=$2
	local Value

	if command -v exiftool >/dev/null; then
		Value=$(timeout 10s exiftool -s3 -"$Tag" -- "$File" 2>/dev/null)
	elif command -v identify >/dev/null; then
		Value=$(
			timeout 10s identify -ping -format "%[exif:${Tag}]" -- "$File" 2>/dev/null
		)
	elif declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure exiftool; then
		# exiftool was just installed - retry the read with it.
		Value=$(timeout 10s exiftool -s3 -"$Tag" -- "$File" 2>/dev/null)
	else
		return 127
	fi

	[ -n "$Value" ] || return 1
	printf '%s' "$Value"
}

# Internal helper: true when at least one EXIF reader is installed.
_Exif_Has_Reader() {
	command -v exiftool >/dev/null || command -v identify >/dev/null
}

# Internal helper: true when the tool exists - otherwise propose installing
# it through the deps module (when loaded) and report the outcome.
# _Exif_Have <tool>
_Exif_Have() {
	local Tool=$1

	command -v "$Tool" >/dev/null 2>&1 && return 0
	declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure "$Tool"
}

# ---------------------------------------------------------------------------
# Generic access and dumps
# ---------------------------------------------------------------------------

# Get_EXIF <Tag> <file> - read any EXIF tag by its exiftool name
# (e.g. DateTimeOriginal, ISO, GPSLatitude).
Get_EXIF() {
	local Tag=$1
	local File=$2

	[ -n "$Tag" ] && [ -f "$File" ] || return 1
	_Exif_Read "$Tag" "$File"
}

# Print every EXIF tag as "Tag: Value", one per line (exiftool only).
Get_EXIF_All() {
	local File=$1
	local Dump

	[ -f "$File" ] || return 1
	_Exif_Have exiftool || return 127

	Dump=$(timeout 10s exiftool -s -- "$File" 2>/dev/null)
	[ -n "$Dump" ] || return 1
	printf '%s\n' "$Dump"
}

# Print only the tag names present in the file (exiftool only).
Get_EXIF_Tags() {
	local File=$1
	local Tags

	Tags=$(Get_EXIF_All "$File") || return $?
	printf '%s\n' "$Tags" | sed 's/ :.*//' | grep -v '^$'
}

# Predicate: does the file carry any EXIF metadata at all?
EXIF_Is_Present() {
	local File=$1

	[ -f "$File" ] || return 1
	Get_EXIF_All "$File" >/dev/null
}

# ---------------------------------------------------------------------------
# Date and camera getters
# ---------------------------------------------------------------------------

Get_EXIF_Date() {
	local File=$1
	local Date

	Date=$(_Exif_Read DateTimeOriginal "$File") || return $?
	printf '%s' "$Date"
}

Get_EXIF_CreateDate() {
	local File=$1
	local Date

	Date=$(_Exif_Read CreateDate "$File") || return $?
	printf '%s' "$Date"
}

Get_EXIF_Camera() {
	local File=$1
	local Make Model

	_Exif_Has_Reader || return 127
	Make=$(_Exif_Read Make "$File") || Make=''
	Model=$(_Exif_Read Model "$File") || Model=''

	[ -n "$Make" ] || [ -n "$Model" ] || return 1
	printf '%s %s' "$Make" "$Model"
}

Get_EXIF_Lens() {
	local File=$1
	local Lens

	_Exif_Has_Reader || return 127
	Lens=$(_Exif_Read LensModel "$File") || Lens=$(_Exif_Read LensMake "$File") || return 1
	printf '%s' "$Lens"
}

# ---------------------------------------------------------------------------
# Exposure getters
# ---------------------------------------------------------------------------

Get_EXIF_ISO() {
	local File=$1
	local Iso

	Iso=$(_Exif_Read ISO "$File") || return $?
	printf '%s' "$Iso"
}

Get_EXIF_Exposure() {
	local File=$1
	local Exposure

	Exposure=$(_Exif_Read ExposureTime "$File") || return $?
	printf '%s' "$Exposure"
}

Get_EXIF_Aperture() {
	local File=$1
	local Aperture

	Aperture=$(_Exif_Read FNumber "$File") || return $?
	printf '%s' "$Aperture"
}

Get_EXIF_FocalLength() {
	local File=$1
	local Focal

	Focal=$(_Exif_Read FocalLength "$File") || return $?
	printf '%s' "$Focal"
}

Get_EXIF_Flash() {
	local File=$1
	local Flash

	Flash=$(_Exif_Read Flash "$File") || return $?
	printf '%s' "$Flash"
}

Get_EXIF_Orientation() {
	local File=$1
	local Orientation

	Orientation=$(_Exif_Read Orientation "$File") || return $?
	printf '%s' "$Orientation"
}

# ---------------------------------------------------------------------------
# GPS getters (decimal degrees where the reader supports it)
# ---------------------------------------------------------------------------

Get_EXIF_GPS_Lat() {
	local File=$1
	local Lat

	if command -v exiftool >/dev/null; then
		Lat=$(timeout 10s exiftool -s3 -c '%.6f' -GPSLatitude -- "$File" 2>/dev/null)
	else
		Lat=$(_Exif_Read GPSLatitude "$File") || return $?
	fi

	[ -n "$Lat" ] || return 1
	printf '%s' "$Lat"
}

Get_EXIF_GPS_Lon() {
	local File=$1
	local Lon

	if command -v exiftool >/dev/null; then
		Lon=$(timeout 10s exiftool -s3 -c '%.6f' -GPSLongitude -- "$File" 2>/dev/null)
	else
		Lon=$(_Exif_Read GPSLongitude "$File") || return $?
	fi

	[ -n "$Lon" ] || return 1
	printf '%s' "$Lon"
}

Get_EXIF_GPS() {
	local File=$1
	local Lat Lon

	_Exif_Has_Reader || return 127
	Lat=$(Get_EXIF_GPS_Lat "$File") || Lat=''
	Lon=$(Get_EXIF_GPS_Lon "$File") || Lon=''

	[ -n "$Lat" ] || [ -n "$Lon" ] || return 1
	printf '%s,%s' "$Lat" "$Lon"
}

Get_EXIF_GPS_Alt() {
	local File=$1
	local Alt

	Alt=$(_Exif_Read GPSAltitude "$File") || return $?
	printf '%s' "$Alt"
}

# ---------------------------------------------------------------------------
# Author and copyright
# ---------------------------------------------------------------------------

Get_EXIF_Artist() {
	local File=$1
	local Artist

	Artist=$(_Exif_Read Artist "$File") || return $?
	printf '%s' "$Artist"
}

Get_EXIF_Copyright() {
	local File=$1
	local Copyright

	Copyright=$(_Exif_Read Copyright "$File") || return $?
	printf '%s' "$Copyright"
}

# ---------------------------------------------------------------------------
# Actions: strip, set, copy
# ---------------------------------------------------------------------------

# Write a metadata-stripped copy of In to Out.
EXIF_Strip() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1

	if command -v exiftool >/dev/null; then
		timeout 60s exiftool -all= -o "$Out" -- "$In" >/dev/null 2>&1
	elif command -v magick >/dev/null; then
		timeout 120s magick "$In" -strip "$Out" >/dev/null 2>&1
	elif command -v convert >/dev/null; then
		timeout 120s convert "$In" -strip "$Out" >/dev/null 2>&1
	else
		return 127
	fi
}

# Set one EXIF tag in place: EXIF_Set <Tag> <Value> <file>.
EXIF_Set() {
	local Tag=$1
	local Value=$2
	local File=$3

	[ -n "$Tag" ] && [ -n "$Value" ] && [ -f "$File" ] || return 1
	_Exif_Have exiftool || return 127

	timeout 60s exiftool -overwrite_original "-$Tag=$Value" -- "$File" >/dev/null 2>&1
}

# Copy all EXIF tags from Src onto Dst in place: EXIF_Copy <src> <dst>.
EXIF_Copy() {
	local Src=$1
	local Dst=$2

	[ -f "$Src" ] && [ -f "$Dst" ] || return 1
	_Exif_Have exiftool || return 127

	timeout 60s exiftool -overwrite_original -tagsfromfile "$Src" -exif:all -- "$Dst" >/dev/null 2>&1
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
