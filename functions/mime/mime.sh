#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : mime.sh                                                           #
# Version : 2.0                                                               #
# Desc    : Complete MIME toolkit - file(1) / magic bytes / extension maps    #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of MIME tools built on file(1): MIME type,
# main/sub parts, human description, charset, magic bytes (hex and
# print-string), magic-number detection, bidirectional MIME <-> extension
# mapping, filename-to-MIME guessing, pattern matching and main-type
# predicates. Every function takes a path as its first argument, prints its
# result on stdout and returns non-zero on failure. No globals required.

# ---------------------------------------------------------------------------
# Core getters (file(1))
# ---------------------------------------------------------------------------

Get_MIME_Type() {
	local File=$1
	local MIME

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	[ -n "$MIME" ] || return 1
	printf '%s' "$MIME"
}

Get_MIME_Main() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	printf '%s' "${MIME%%/*}"
}

Get_MIME_Sub() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	printf '%s' "${MIME#*/}"
}

Get_MIME_Description() {
	local File=$1
	local Desc

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Desc=$(file -b -- "$File" 2>/dev/null)
	[ -n "$Desc" ] || return 1
	printf '%s' "$Desc"
}

Get_MIME_Charset() {
	local File=$1
	local Charset

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Charset=$(file -b --mime-encoding -- "$File" 2>/dev/null)
	[ -n "$Charset" ] || return 1
	printf '%s' "$Charset"
}

# Print a human-readable summary block for one file.
Get_MIME_All() {
	local File=$1
	local Type Desc Charset Ext Magic

	Type=$(Get_MIME_Type "$File") || return $?
	Desc=$(Get_MIME_Description "$File" 2>/dev/null || true)
	Charset=$(Get_MIME_Charset "$File" 2>/dev/null || true)
	Ext=$(Get_MIME_Extension "$File" 2>/dev/null || true)
	Magic=$(Get_Magic_Bytes "$File" 8 2>/dev/null || true)

	printf 'Type:        %s\n' "$Type"
	printf 'Main:        %s\n' "${Type%%/*}"
	printf 'Sub:         %s\n' "${Type#*/}"
	printf 'Description: %s\n' "$Desc"
	printf 'Charset:     %s\n' "$Charset"
	printf 'Extension:   %s\n' "$Ext"
	printf 'Magic:       %s\n' "$Magic"
}

# ---------------------------------------------------------------------------
# Magic bytes
# ---------------------------------------------------------------------------

# First bytes of the file as space-separated hex. Get_Magic_Bytes <file> [count]
Get_Magic_Bytes() {
	local File=$1
	local Count=${2:-16}
	local Hex

	[ -f "$File" ] || return 1
	[ "$Count" -gt 0 ] 2>/dev/null || return 1
	command -v od >/dev/null || return 127

	Hex=$(od -An -v -tx1 -N "$Count" -- "$File" 2>/dev/null | tr -s ' \n' ' ')
	Hex=${Hex# }
	Hex=${Hex% }
	[ -n "$Hex" ] || return 1
	printf '%s' "$Hex"
}

# First bytes of the file as a printable string (non-printables become ".").
# Get_Magic_String <file> [count]
Get_Magic_String() {
	local File=$1
	local Count=${2:-16}
	local Str

	[ -f "$File" ] || return 1
	[ "$Count" -gt 0 ] 2>/dev/null || return 1
	command -v head >/dev/null || return 127

	Str=$(head -c "$Count" -- "$File" 2>/dev/null | tr -c '[:print:]' '.')
	[ -n "$Str" ] || return 1
	printf '%s' "$Str"
}

# Detect the MIME type from the magic number alone (no extension involved).
# Returns false for unknown magic.
Get_MIME_By_Magic() {
	local File=$1
	local Hex Sub

	Hex=$(Get_Magic_Bytes "$File" 16) || return $?
	Hex=${Hex// /}

	case "$Hex" in
	ffd8ff*) printf 'image/jpeg' ;;
	89504e47*) printf 'image/png' ;;
	47494638*) printf 'image/gif' ;;
	424d*) printf 'image/bmp' ;;
	25504446*) printf 'application/pdf' ;;
	504b03* | 504b05* | 504b07*) printf 'application/zip' ;;
	1f8b*) printf 'application/gzip' ;;
	425a68*) printf 'application/x-bzip2' ;;
	fd377a585a00*) printf 'application/x-xz' ;;
	377abcaf271c*) printf 'application/x-7z-compressed' ;;
	526172211a07*) printf 'application/vnd.rar' ;;
	7f454c46*) printf 'application/x-elf' ;;
	4d5a*) printf 'application/x-dosexec' ;;
	0061736d*) printf 'application/wasm' ;;
	53514c697465*) printf 'application/vnd.sqlite3' ;;
	494433*) printf 'audio/mpeg' ;;
	fffb* | fff3* | fff9* | ffa*) printf 'audio/mpeg' ;;
	4f676753*) printf 'audio/ogg' ;;
	664c6143*) printf 'audio/flac' ;;
	000001*) printf 'video/mpeg' ;;
	1a45dfa3*) printf 'video/x-matroska' ;;
	????????66747970*) printf 'video/mp4' ;;
	52494646*)
		# RIFF container: decide by the form type at offset 8.
		Sub=$(Get_Magic_Bytes "$File" 12) || return $?
		Sub=${Sub// /}
		case "$Sub" in
		????????????????57454250*) printf 'image/webp' ;;
		????????????????57415645*) printf 'audio/x-wav' ;;
		*) printf 'application/x-riff' ;;
		esac
		;;
	*) return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# MIME <-> extension mapping (common types)
# ---------------------------------------------------------------------------

# Canonical extension for a MIME type. Get_MIME_Extension <file>
Get_MIME_Extension() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "$MIME" in
	text/plain) printf 'txt' ;;
	text/markdown) printf 'md' ;;
	text/html) printf 'html' ;;
	text/css) printf 'css' ;;
	text/csv) printf 'csv' ;;
	text/x-shellscript) printf 'sh' ;;
	text/x-python) printf 'py' ;;
	text/x-c) printf 'c' ;;
	text/x-c++) printf 'cpp' ;;
	text/xml | application/xml) printf 'xml' ;;
	application/json) printf 'json' ;;
	application/pdf) printf 'pdf' ;;
	application/postscript) printf 'ps' ;;
	application/rtf) printf 'rtf' ;;
	image/png) printf 'png' ;;
	image/jpeg) printf 'jpg' ;;
	image/gif) printf 'gif' ;;
	image/bmp) printf 'bmp' ;;
	image/svg+xml) printf 'svg' ;;
	image/webp) printf 'webp' ;;
	image/x-icon) printf 'ico' ;;
	image/tiff) printf 'tiff' ;;
	audio/mpeg) printf 'mp3' ;;
	audio/x-wav | audio/wav | audio/vnd.wave) printf 'wav' ;;
	audio/ogg) printf 'ogg' ;;
	audio/flac) printf 'flac' ;;
	audio/mp4) printf 'm4a' ;;
	video/mp4) printf 'mp4' ;;
	video/x-matroska) printf 'mkv' ;;
	video/webm) printf 'webm' ;;
	video/x-msvideo) printf 'avi' ;;
	video/quicktime) printf 'mov' ;;
	video/mpeg) printf 'mpg' ;;
	application/zip) printf 'zip' ;;
	application/gzip) printf 'gz' ;;
	application/x-bzip2) printf 'bz2' ;;
	application/x-xz) printf 'xz' ;;
	application/x-7z-compressed) printf '7z' ;;
	application/vnd.rar) printf 'rar' ;;
	application/x-elf) printf 'elf' ;;
	application/x-dosexec) printf 'exe' ;;
	application/wasm) printf 'wasm' ;;
	application/vnd.sqlite3) printf 'sqlite' ;;
	application/msword) printf 'doc' ;;
	application/vnd.openxmlformats-officedocument.wordprocessingml.document) printf 'docx' ;;
	application/vnd.ms-excel) printf 'xls' ;;
	application/vnd.openxmlformats-officedocument.spreadsheetml.sheet) printf 'xlsx' ;;
	application/vnd.ms-powerpoint) printf 'ppt' ;;
	application/vnd.openxmlformats-officedocument.presentationml.presentation) printf 'pptx' ;;
	*) return 1 ;;
	esac
}

# MIME type for an extension (no file needed). Get_Extension_MIME <ext>
Get_Extension_MIME() {
	local Ext=${1,,}
	Ext=${Ext#.}

	case "$Ext" in
	txt | text | log) printf 'text/plain' ;;
	md | markdown) printf 'text/markdown' ;;
	html | htm) printf 'text/html' ;;
	css) printf 'text/css' ;;
	csv) printf 'text/csv' ;;
	sh | bash) printf 'text/x-shellscript' ;;
	py) printf 'text/x-python' ;;
	c) printf 'text/x-c' ;;
	cpp | cc | cxx) printf 'text/x-c++' ;;
	xml) printf 'application/xml' ;;
	json) printf 'application/json' ;;
	pdf) printf 'application/pdf' ;;
	ps) printf 'application/postscript' ;;
	rtf) printf 'application/rtf' ;;
	png) printf 'image/png' ;;
	jpg | jpeg) printf 'image/jpeg' ;;
	gif) printf 'image/gif' ;;
	bmp) printf 'image/bmp' ;;
	svg) printf 'image/svg+xml' ;;
	webp) printf 'image/webp' ;;
	ico) printf 'image/x-icon' ;;
	tiff | tif) printf 'image/tiff' ;;
	mp3) printf 'audio/mpeg' ;;
	wav) printf 'audio/x-wav' ;;
	ogg | oga) printf 'audio/ogg' ;;
	flac) printf 'audio/flac' ;;
	m4a) printf 'audio/mp4' ;;
	mp4 | m4v) printf 'video/mp4' ;;
	mkv) printf 'video/x-matroska' ;;
	webm) printf 'video/webm' ;;
	avi) printf 'video/x-msvideo' ;;
	mov) printf 'video/quicktime' ;;
	mpg | mpeg) printf 'video/mpeg' ;;
	zip) printf 'application/zip' ;;
	gz | gzip) printf 'application/gzip' ;;
	bz2) printf 'application/x-bzip2' ;;
	xz) printf 'application/x-xz' ;;
	7z) printf 'application/x-7z-compressed' ;;
	rar) printf 'application/vnd.rar' ;;
	tar) printf 'application/x-tar' ;;
	iso) printf 'application/x-iso9660-image' ;;
	elf) printf 'application/x-elf' ;;
	exe | dll) printf 'application/x-dosexec' ;;
	wasm) printf 'application/wasm' ;;
	sqlite | db) printf 'application/vnd.sqlite3' ;;
	doc) printf 'application/msword' ;;
	docx) printf 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ;;
	xls) printf 'application/vnd.ms-excel' ;;
	xlsx) printf 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ;;
	ppt) printf 'application/vnd.ms-powerpoint' ;;
	pptx) printf 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ;;
	*) return 1 ;;
	esac
}

# Guess the MIME type from a filename alone (no file needed).
# Returns false when the extension is unknown.
Get_Name_MIME() {
	local Name=${1##*/}
	local Ext=${Name##*.}

	[ -n "$Name" ] || return 1
	[[ "$Name" == *.* && "$Name" != .* || "$Name" == *.*.* ]] || return 1

	Get_Extension_MIME "$Ext"
}

# ---------------------------------------------------------------------------
# Matching and predicates
# ---------------------------------------------------------------------------

# Predicate: does the file's MIME type match the pattern?
# Shell wildcards allowed: "image/*", "*/png", "text/plain".
MIME_Match() {
	local File=$1
	local Pattern=${2,,}
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "${MIME,,}" in
	$Pattern) return 0 ;;
	*) return 1 ;;
	esac
}

MIME_Is_Text() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	[[ "${MIME%%/*}" == "text" ]]
}

MIME_Is_Binary() {
	local File=$1
	local Charset

	Charset=$(Get_MIME_Charset "$File") || return $?
	[[ "$Charset" == "binary" ]]
}

MIME_Is_Image() {
	local File=$1

	[[ "$(Get_MIME_Main "$File")" == "image" ]]
}

MIME_Is_Video() {
	local File=$1

	[[ "$(Get_MIME_Main "$File")" == "video" ]]
}

MIME_Is_Audio() {
	local File=$1

	[[ "$(Get_MIME_Main "$File")" == "audio" ]]
}

MIME_Is_Archive() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "$MIME" in
	application/zip | application/gzip | application/x-gzip | application/x-bzip2 | application/x-xz | application/x-7z-compressed | application/vnd.rar | application/x-tar | application/x-iso9660-image | application/x-cpio | application/x-archive) return 0 ;;
	*) return 1 ;;
	esac
}

MIME_Is_Document() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?

	case "$MIME" in
	application/pdf | application/postscript | application/rtf | application/msword | application/vnd.ms-excel | application/vnd.ms-powerpoint | application/vnd.openxmlformats-officedocument.* | application/vnd.oasis.opendocument.*) return 0 ;;
	*) return 1 ;;
	esac
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
