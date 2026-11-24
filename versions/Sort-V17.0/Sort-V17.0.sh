#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort.sh                                                           #
# Version : 17.0                                                              #
# Desc    : Self-contained threaded organizer - all lineage features merged    #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A self-contained rewrite of the Sort mainline: every needed function from
# the functions/ toolkit is embedded below (no external FUNCTIONS sourcing).
# Features merged from the whole V1.0-V15.1 lineage: mode selector with
# trash/shred, dynamic --dirs/--subdirs/--rename/--extension values (dates,
# checksums, media tiers, metadata), --type filter, --target, --pause,
# --log/--undo, --hidden/--links/--recursive, EXIF levels/stripping, metadata
# titles, threading, colored verbose output and the deps init-system.

# ===========================================================================
# COLORS MODULE
# ===========================================================================

# A complete, standalone bag of color and print tools: the C_* ANSI color
# variables for direct use in echo/printf, plus Print_* helpers for plain
# messages, info, ok, errors, warnings, timestamped logs, debug lines,
# headers and separators. Colors switch on automatically when stdout or
# stderr is a terminal and switch off for pipes/files or when NO_COLOR is
# set. Color_Enable / Color_Disable override the detection. No globals
# beyond the C_* variables and COLORS_ON defined by this module.

# ---------------------------------------------------------------------------
# Color state
# ---------------------------------------------------------------------------

COLORS_ON=0
if [ -z "${NO_COLOR:-}" ] && { [ -t 1 ] || [ -t 2 ]; }; then
	COLORS_ON=1
fi

# Internal: (re)assign the C_* variables according to COLORS_ON.
_Color_Set() {
	if [ "$COLORS_ON" = "1" ]; then
		C_RESET=$'\033[0m'
		C_BOLD=$'\033[1m'
		C_DIM=$'\033[2m'
		C_UNDERLINE=$'\033[4m'
		C_RED=$'\033[31m'
		C_GREEN=$'\033[32m'
		C_YELLOW=$'\033[33m'
		C_BLUE=$'\033[34m'
		C_MAGENTA=$'\033[35m'
		C_CYAN=$'\033[36m'
		C_WHITE=$'\033[37m'
		C_GRAY=$'\033[90m'
	else
		C_RESET=''
		C_BOLD=''
		C_DIM=''
		C_UNDERLINE=''
		C_RED=''
		C_GREEN=''
		C_YELLOW=''
		C_BLUE=''
		C_MAGENTA=''
		C_CYAN=''
		C_WHITE=''
		C_GRAY=''
	fi
}

_Color_Set

Color_Enable() {
	COLORS_ON=1
	_Color_Set
}

Color_Disable() {
	COLORS_ON=0
	_Color_Set
}

# ---------------------------------------------------------------------------
# Generic printing
# ---------------------------------------------------------------------------

# Print_Color <name> <text...> - print text in a named color (with reset).
# Names: red green yellow blue magenta cyan white gray bold dim underline.
Print_Color() {
	local Name=${1,,}
	shift

	local Color
	case "$Name" in
	red) Color=$C_RED ;;
	green) Color=$C_GREEN ;;
	yellow) Color=$C_YELLOW ;;
	blue) Color=$C_BLUE ;;
	magenta) Color=$C_MAGENTA ;;
	cyan) Color=$C_CYAN ;;
	white) Color=$C_WHITE ;;
	gray) Color=$C_GRAY ;;
	bold) Color=$C_BOLD ;;
	dim) Color=$C_DIM ;;
	underline) Color=$C_UNDERLINE ;;
	*) Color='' ;;
	esac

	printf '%s%s%s\n' "$Color" "$*" "$C_RESET"
}

# Print a separator line. Print_Line [char] [width]
Print_Line() {
	local Char=${1:--}
	local Width=${2:-80}
	local Line

	# Build the line without external tools.
	Line=$(printf '%*s' "$Width" '' | tr ' ' "$Char")
	printf '%s\n' "$Line"
}

# Print a bold header with a separator line underneath.
Print_Header() {
	printf '%s%s%s\n' "$C_BOLD" "$C_CYAN" "$*"
	Print_Line
}

# ---------------------------------------------------------------------------
# Message levels
# ---------------------------------------------------------------------------

# Plain message on stdout.
Print_Message() {
	printf '%s%s%s\n' "$C_WHITE" "$*" "$C_RESET"
}

# Informational message on stdout (cyan).
Print_Info() {
	printf '%s%s%s\n' "$C_CYAN" "$*" "$C_RESET"
}

# Success message on stdout (green).
Print_Ok() {
	printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"
}

# Error message on stderr (red, "Error: " prefix). Returns false so it can
# be used directly as a failure statement.
Print_Error() {
	printf '%sError: %s%s\n' "$C_RED" "$*" "$C_RESET" >&2
	return 1
}

# Warning message on stderr (yellow, "Warning: " prefix).
Print_Warning() {
	printf '%sWarning: %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2
	return 0
}

# Timestamped log line on stderr. Print_Log <text...>
Print_Log() {
	local Stamp

	Stamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
	printf '%s[%s]%s %s\n' "$C_DIM" "$Stamp" "$C_RESET" "$*" >&2
	return 0
}

# Debug line on stderr (magenta), printed only when DEBUG=1.
Print_Debug() {
	[ "${DEBUG:-0}" = "1" ] || return 0
	printf '%s[DEBUG]%s %s\n' "$C_MAGENTA" "$C_RESET" "$*" >&2
	return 0
}

# ---------------------------------------------------------------------------
# Preview
# ---------------------------------------------------------------------------

# Print one line of every color, to check terminal support.
Color_Preview() {
	local Name
	for Name in red green yellow blue magenta cyan white gray bold dim underline; do
		Print_Color "$Name" "$Name"
	done
	return 0
}

# ===========================================================================
# SYSTEM MODULE
# ===========================================================================

# Process control helpers: clean exit and Ctrl+C break handling.

Exit() {
	local Status=${1:-0}

	# Prevent this EXIT handler from recursively invoking itself when exit runs.
	trap - EXIT

	printf 'Waiting for background jobs to finish...\n'
	wait

	# Restore the original shell field separator.
	IFS=$OIFS

	printf 'Finished.\n'
	exit "$Status"
}

Break() {
	printf '\nTerminated by user!\n'
	Exit 130
}

# ===========================================================================
# UI MODULE
# ===========================================================================

# Terminal display helpers: themed separator lines for the TUI output.

Draw_Line() {
	local Width Symbol

	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	Symbol=${1:-=}

	# Use the requested symbol for every column in the separator.
	printf '\n%*s\n\n' "$Width" '' | tr ' ' "$Symbol"
}

# ===========================================================================
# DEPS MODULE
# ===========================================================================

# An init-system for tools outside base-linux: detects the system package
# manager (apt-get, dnf, yum, pacman, zypper, apk, xbps-install) and the
# privilege escalator (root, sudo, su). On first use of a missing external
# tool it proposes the installation, asks for confirmation and runs it.
# Set DEPS_YES=1 to install without asking. Every function returns true (0)
# on success and false (non-zero) otherwise. No globals required.

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

# Predicate: is the tool available on PATH?
Deps_Has() {
	local Tool=$1

	[ -n "$Tool" ] || return 1
	command -v "$Tool" >/dev/null 2>&1
}

# Print the tools from the given list that are missing. Returns true when
# nothing is missing, false when at least one is.
Deps_Missing() {
	local Tool
	local Out=""

	[ $# -gt 0 ] || return 0

	for Tool in "$@"; do
		Deps_Has "$Tool" || Out="$Out $Tool"
	done

	[ -z "$Out" ] && return 0
	printf '%s\n' "${Out# }"
	return 1
}

# Print the detected system package manager (empty output = none found).
Deps_Installer() {
	local Installer

	for Installer in apt-get dnf yum pacman zypper apk xbps-install; do
		if command -v "$Installer" >/dev/null 2>&1; then
			printf '%s' "$Installer"
			return 0
		fi
	done

	return 1
}

# Print the privilege escalator: nothing when already root, otherwise
# "sudo" or "su". Returns false when none can be found.
Deps_Priv() {
	if [ "$(id -u 2>/dev/null)" = "0" ]; then
		return 0
	elif command -v sudo >/dev/null 2>&1; then
		printf 'sudo'
		return 0
	elif command -v su >/dev/null 2>&1; then
		printf 'su'
		return 0
	fi

	return 1
}

# ---------------------------------------------------------------------------
# Mapping: tool -> package name for the detected installer
# Deps_Package <tool> [installer]
# ---------------------------------------------------------------------------

Deps_Package() {
	local Tool=${1,,}
	local Installer

	Installer=${2:-$(Deps_Installer)} || return 1

	case "$Tool:$Installer" in
	exiftool:apt-get | exiftool:apt) printf 'libimage-exiftool-perl' ;;
	exiftool:dnf | exiftool:yum) printf 'perl-Image-ExifTool' ;;
	exiftool:*) printf 'exiftool' ;;
	ffprobe:* | ffmpeg:* | ffplay:*) printf 'ffmpeg' ;;
	identify:* | magick:* | convert:* | compare:*) printf 'imagemagick' ;;
	file:*) printf 'file' ;;
	tar:* | gzip:* | gunzip:* | bzip2:* | bunzip2:* | xz:* | unxz:* | zstd:* | unzip:* | zip:*)
		printf '%s' "$Tool"
		;;
	7z:apt-get | 7z:apt) printf 'p7zip-full' ;;
	7z:*) printf 'p7zip' ;;
	unrar:*) printf 'unrar' ;;
	trash-put:* | trash:*) printf 'trash-cli' ;;
	md5sum:* | sha1sum:* | sha224sum:* | sha256sum:* | sha384sum:* | sha512sum:* | b2sum:* | cksum:* | cmp:* | stat:* | timeout:* | od:* | wc:* | du:* | head:* | tail:*)
		printf 'coreutils'
		;;
	*) return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

# Run the installer for the given packages (privilege-aware).
# Deps_Install <package>...
Deps_Install() {
	local Installer Priv
	local Flags=()
	local Cmd=()

	[ $# -gt 0 ] || return 1

	Installer=$(Deps_Installer) || {
		printf 'deps: no supported package manager found\n' >&2
		return 1
	}

	Priv=$(Deps_Priv) || {
		printf 'deps: no way to gain root (run as root or install sudo)\n' >&2
		return 1
	}

	case "$Installer" in
	apt-get) Flags=(install -y) ;;
	dnf) Flags=(install -y) ;;
	yum) Flags=(install -y) ;;
	pacman) Flags=(-S --noconfirm --needed) ;;
	zypper) Flags=(--non-interactive install) ;;
	apk) Flags=(add) ;;
	xbps-install) Flags=(-Sy) ;;
	*) return 1 ;;
	esac

	Cmd=("$Installer" "${Flags[@]}" "$@")

	if [ "$(id -u 2>/dev/null)" = "0" ]; then
		"${Cmd[@]}"
	elif [ "$Priv" = "sudo" ]; then
		sudo "${Cmd[@]}"
	else
		su -c "${Cmd[*]}"
	fi
}

# Internal: propose an install (asking unless DEPS_YES=1), then run it.
# _Deps_Propose_Install <package>...
_Deps_Propose_Install() {
	local Answer
	local Packages=("$@")

	[ $# -gt 0 ] || return 1

	if [ "${DEPS_YES:-0}" != "1" ]; then
		printf 'deps: proposed install: %s\n' "$*" >&2

		# Ask for confirmation on a terminal; without one, only DEPS_YES=1 installs.
		if [ -t 0 ]; then
			printf 'deps: install now? [y/N] ' >&2
			read -r Answer || Answer=""
		elif [ -e /dev/tty ]; then
			printf 'deps: install now? [y/N] ' >&2
			read -r Answer 2>/dev/null </dev/tty || Answer=""
		else
			printf 'deps: not installed (set DEPS_YES=1 to install without asking)\n' >&2
			return 1
		fi

		case "$Answer" in
		y | Y | yes | YES | Yes) ;;
		*)
			printf 'deps: skipped\n' >&2
			return 1
			;;
		esac
	fi

	Deps_Install "${Packages[@]}"
}

# ---------------------------------------------------------------------------
# Ensure one tool: true when present (installing it if accepted).
# Deps_Ensure <tool> [package]
# ---------------------------------------------------------------------------

Deps_Ensure() {
	local Tool=$1
	local Package=${2:-}

	Deps_Has "$Tool" && return 0

	[ -n "$Package" ] || Package=$(Deps_Package "$Tool") || {
		printf "deps: '%s' is missing and its package name is unknown\n" "$Tool" >&2
		return 1
	}

	_Deps_Propose_Install "$Package" || return 1

	# True only if the tool is usable after the install.
	Deps_Has "$Tool"
}

# ---------------------------------------------------------------------------
# Init-system entry point: check a whole list at once.
# Deps_Init <tool[:package]>...   e.g. Deps_Init ffprobe identify exiftool
# Returns true when everything is present (or got installed), false otherwise.
# ---------------------------------------------------------------------------

Deps_Init() {
	local Spec Tool Package
	local Missing=()
	local Packages=()

	[ $# -gt 0 ] && [ -n "${1:-}" ] || return 0

	for Spec in "$@"; do
		Tool=${Spec%%:*}
		Package=${Spec#*:}
		[ "$Package" != "$Spec" ] || Package=""

		if Deps_Has "$Tool"; then
			continue
		fi

		Missing+=("$Tool")

		if [ -z "$Package" ]; then
			Package=$(Deps_Package "$Tool") || Package=""
		fi

		[ -n "$Package" ] && Packages+=("$Package")
	done

	[ ${#Missing[@]} -gt 0 ] || return 0

	printf 'deps: missing: %s\n' "${Missing[*]}" >&2

	[ ${#Packages[@]} -gt 0 ] || return 1

	# One single install proposal for everything that is missing.
	_Deps_Propose_Install "${Packages[@]}" || return 1

	# True only if every requested tool is usable now.
	Deps_Missing "${Missing[@]}" >/dev/null
}

# ===========================================================================
# FILE MODULE
# ===========================================================================

# A complete, standalone bag of file tools: MIME detection, name/extension
# splitting, sizes, timestamps, permissions, ownership, predicates and more.
# Every function takes a path as its first argument, prints its result on
# stdout and returns non-zero on failure. No globals required.

# ---------------------------------------------------------------------------
# Identity: MIME, type, encoding
# ---------------------------------------------------------------------------

Get_MIME() {
	local File=$1
	local MIME

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	MIME=$(file -b --mime-type -- "$File" 2>/dev/null)
	printf '%s' "${MIME:-ERROR}"
}

Get_MIME_Main() {
	local File=$1
	local MIME

	MIME=$(Get_MIME "$File") || return 1
	[[ "$MIME" == "ERROR" ]] && return 1
	printf '%s' "${MIME%%/*}"
}

Get_MIME_Sub() {
	local File=$1
	local MIME

	MIME=$(Get_MIME "$File") || return 1
	[[ "$MIME" == "ERROR" ]] && return 1
	printf '%s' "${MIME#*/}"
}

Get_File_Description() {
	local File=$1
	local Desc

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Desc=$(file -b -- "$File" 2>/dev/null)
	printf '%s' "${Desc:-ERROR}"
}

Get_File_Encoding() {
	local File=$1
	local Enc

	[ -e "$File" ] || return 1
	command -v file >/dev/null || return 127

	Enc=$(file -b --mime-encoding -- "$File" 2>/dev/null)
	printf '%s' "${Enc:-ERROR}"
}

Get_File_Type() {
	local File=$1
	local Type

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Type=$(stat -c '%F' -- "$File" 2>/dev/null)
	printf '%s' "${Type:-ERROR}"
}

# ---------------------------------------------------------------------------
# Name splitting
# ---------------------------------------------------------------------------

Get_File_Name() {
	local Name=${1##*/}
	printf '%s' "${Name%.*}"
}

Get_File_Base() {
	local Name=${1##*/}
	printf '%s' "$Name"
}

Get_File_Ext() {
	local BaseName=${1##*/}

	if [[ "$BaseName" != *.* || "$BaseName" == .* && "$BaseName" != *.*.* ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}

Get_File_Dir() {
	local Dir=${1%/*}
	[[ "$Dir" == "$1" ]] && Dir='.'
	printf '%s' "$Dir"
}

# ---------------------------------------------------------------------------
# Size
# ---------------------------------------------------------------------------

Get_File_Size() {
	local File=$1
	local Size

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	printf '%d' "${Size:-0}"
}

Get_File_Size_Human() {
	local File=$1
	local Size

	[ -e "$File" ] || return 1
	command -v du >/dev/null || return 127

	Size=$(du -h -- "$File" 2>/dev/null | cut -f1)
	printf '%s' "${Size:-ERROR}"
}

Get_File_Block_Size() {
	local File=$1
	local Size

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Size=$(stat -c '%b * %B' -- "$File" 2>/dev/null)
	[ -n "$Size" ] || return 1
	echo $((Size))
}

Get_File_Line_Count() {
	local File=$1
	local Count

	[ -f "$File" ] || return 1
	command -v wc >/dev/null || return 127

	Count=$(wc -l <"$File" 2>/dev/null)
	printf '%d' "${Count:-0}"
}

Get_File_Header_Hex() {
	local File=$1
	local Bytes=${2:-8}
	local Hex

	[ -f "$File" ] || return 1
	command -v od >/dev/null || return 127

	Hex=$(od -An -tx1 -N "$Bytes" -- "$File" 2>/dev/null | tr -d ' \n')
	printf '%s' "$Hex"
}

# ---------------------------------------------------------------------------
# Timestamps
# ---------------------------------------------------------------------------

Get_File_Birth() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%W' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Creation_Time() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%w' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Access_Time() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%x' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Modification_Time() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Modified_Epoch() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%Y' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Accessed_Epoch() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%X' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Changed_Epoch() {
	local File=$1
	local Time

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Time=$(stat -c '%Z' -- "$File" 2>/dev/null)
	printf '%s' "${Time:-0}"
}

Get_File_Age() {
	local File=$1
	local Now Modified

	Modified=$(Get_File_Modified_Epoch "$File") || return 1
	[[ "$Modified" == "0" ]] && return 1
	Now=$(date +%s)
	printf '%d' "$((Now - Modified))"
}

Get_Date_Part() {
	local File=$1
	local Format=$2
	local Fallback=${3:-}
	local Time

	Time=$(Get_File_Birth "$File")

	if [[ "$Time" != "0" ]]; then
		date -d "@$Time" "$Format" 2>/dev/null || printf '%s' "$Fallback"
	else
		printf '%s' "$Fallback"
	fi
}

# ---------------------------------------------------------------------------
# Permissions, ownership, links
# ---------------------------------------------------------------------------

Get_File_Perm() {
	local File=$1
	local Perm

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Perm=$(stat -c '%a' -- "$File" 2>/dev/null)
	printf '%s' "${Perm:-ERROR}"
}

Get_File_Owner() {
	local File=$1
	local Owner

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Owner=$(stat -c '%U:%G' -- "$File" 2>/dev/null)
	printf '%s' "${Owner:-ERROR}"
}

Get_File_Inode() {
	local File=$1
	local Inode

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Inode=$(stat -c '%i' -- "$File" 2>/dev/null)
	printf '%s' "${Inode:-ERROR}"
}

Get_File_Links() {
	local File=$1
	local Links

	[ -e "$File" ] || return 1
	command -v stat >/dev/null || return 127

	Links=$(stat -c '%h' -- "$File" 2>/dev/null)
	printf '%s' "${Links:-ERROR}"
}

Get_Symlink_Target() {
	local File=$1

	[ -L "$File" ] || return 1
	readlink -- "$File"
}

# ---------------------------------------------------------------------------
# Predicates (return 0 = yes, 1 = no)
# ---------------------------------------------------------------------------

File_Exists() {
	[ -e "$1" ]
}

File_Is_Symlink() {
	[ -L "$1" ]
}

File_Is_Hidden() {
	local Base=${1##*/}
	[[ "$Base" == .* ]]
}

File_Is_Empty() {
	[ -f "$1" ] && [ ! -s "$1" ]
}

File_Is_Readable() {
	[ -r "$1" ]
}

File_Is_Writable() {
	[ -w "$1" ]
}

File_Is_Executable() {
	[ -x "$1" ]
}

File_Is_Text() {
	[[ "$(Get_File_Encoding "$1" 2>/dev/null)" != "binary" ]]
}

File_Is_Binary() {
	[[ "$(Get_File_Encoding "$1" 2>/dev/null)" == "binary" ]]
}

# ===========================================================================
# MIME MODULE
# ===========================================================================

# A complete, standalone bag of MIME tools built on file(1): MIME type,
# main/sub parts, human description, charset, magic bytes (hex and
# print-string), magic-number detection, bidirectional MIME <-> extension
# mapping (940 extensions / 700 MIME types distilled from the user's MIME
# database), filename-to-MIME guessing, pattern matching and main-type
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

# Canonical extension for a MIME type (exact table lookup, no file needed).
# _MIME_Lookup_Ext <type>
_MIME_Lookup_Ext() {
	local Type=$1

	case "$Type" in
	application/andrew-inset) printf 'ez' ;;
	application/applixware) printf 'aw' ;;
	application/atom+xml) printf 'atom' ;;
	application/atomcat+xml) printf 'atomcat' ;;
	application/atomsvc+xml) printf 'atomsvc' ;;
	application/ccxml+xml) printf 'ccxml' ;;
	application/cu-seeme) printf 'cu' ;;
	application/davmount+xml) printf 'davmount' ;;
	application/ecmascript) printf 'ecma' ;;
	application/emma+xml) printf 'emma' ;;
	application/epub+zip) printf 'epub' ;;
	application/font-tdpfr) printf 'pfr' ;;
	application/gzip) printf 'gz' ;;
	application/hyperstudio) printf 'stk' ;;
	application/java-archive) printf 'jar' ;;
	application/java-serialized-object) printf 'ser' ;;
	application/java-vm) printf 'class' ;;
	application/json) printf 'json' ;;
	application/lost+xml) printf 'lostxml' ;;
	application/mac-binhex40) printf 'hqx' ;;
	application/mac-compactpro) printf 'cpt' ;;
	application/marc) printf 'mrc' ;;
	application/mathematica) printf 'ma' ;;
	application/mathml+xml) printf 'mathml' ;;
	application/mbox) printf 'mbox' ;;
	application/mediaservercontrol+xml) printf 'mscml' ;;
	application/mp4) printf 'mp4s' ;;
	application/msword) printf 'doc' ;;
	application/mxf) printf 'mxf' ;;
	application/octet-stream) printf 'bin' ;;
	application/oda) printf 'oda' ;;
	application/oebps-package+xml) printf 'opf' ;;
	application/ogg) printf 'ogx' ;;
	application/onenote) printf 'onepkg' ;;
	application/patch-ops-error+xml) printf 'xer' ;;
	application/pdf) printf 'pdf' ;;
	application/pgp-encrypted) printf 'pgp' ;;
	application/pgp-signature) printf 'asc' ;;
	application/pics-rules) printf 'prf' ;;
	application/pkcs10) printf 'p10' ;;
	application/pkcs7-mime) printf 'p7c' ;;
	application/pkcs7-signature) printf 'p7s' ;;
	application/pkix-cert) printf 'cer' ;;
	application/pkix-crl) printf 'crl' ;;
	application/pkix-pkipath) printf 'pkipath' ;;
	application/pkixcmp) printf 'pki' ;;
	application/pls+xml) printf 'pls' ;;
	application/postscript) printf 'ai' ;;
	application/prql) printf 'prql' ;;
	application/prs.cww) printf 'cww' ;;
	application/rdf+xml) printf 'rdf' ;;
	application/reginfo+xml) printf 'rif' ;;
	application/relax-ng-compact-syntax) printf 'rnc' ;;
	application/resource-lists+xml) printf 'rl' ;;
	application/resource-lists-diff+xml) printf 'rld' ;;
	application/rls-services+xml) printf 'rs' ;;
	application/rsd+xml) printf 'rsd' ;;
	application/rss+xml) printf 'rss' ;;
	application/rtf) printf 'rtf' ;;
	application/sbml+xml) printf 'sbml' ;;
	application/scvp-cv-request) printf 'scq' ;;
	application/scvp-cv-response) printf 'scs' ;;
	application/scvp-vp-request) printf 'spq' ;;
	application/scvp-vp-response) printf 'spp' ;;
	application/sdp) printf 'sdp' ;;
	application/set-payment-initiation) printf 'setpay' ;;
	application/set-registration-initiation) printf 'setreg' ;;
	application/shf+xml) printf 'shf' ;;
	application/smil+xml) printf 'smi' ;;
	application/sparql-query) printf 'rq' ;;
	application/sparql-results+xml) printf 'srx' ;;
	application/srgs) printf 'gram' ;;
	application/srgs+xml) printf 'grxml' ;;
	application/ssml+xml) printf 'ssml' ;;
	application/vnd.3gpp.pic-bw-large) printf 'plb' ;;
	application/vnd.3gpp.pic-bw-small) printf 'psb' ;;
	application/vnd.3gpp.pic-bw-var) printf 'pvb' ;;
	application/vnd.3gpp2.tcap) printf 'tcap' ;;
	application/vnd.3m.post-it-notes) printf 'pwn' ;;
	application/vnd.accpac.simply.aso) printf 'aso' ;;
	application/vnd.accpac.simply.imp) printf 'imp' ;;
	application/vnd.acucobol) printf 'acu' ;;
	application/vnd.acucorp) printf 'acutc' ;;
	application/vnd.adobe.air-application-installer-package+zip) printf 'air' ;;
	application/vnd.adobe.xdp+xml) printf 'xdp' ;;
	application/vnd.adobe.xfdf) printf 'xfdf' ;;
	application/vnd.airzip.filesecure.azf) printf 'azf' ;;
	application/vnd.airzip.filesecure.azs) printf 'azs' ;;
	application/vnd.amazon.ebook) printf 'azw' ;;
	application/vnd.americandynamics.acc) printf 'acc' ;;
	application/vnd.amiga.ami) printf 'ami' ;;
	application/vnd.android.package-archive) printf 'apk' ;;
	application/vnd.anser-web-certificate-issue-initiation) printf 'cii' ;;
	application/vnd.anser-web-funds-transfer-initiation) printf 'fti' ;;
	application/vnd.antix.game-component) printf 'atx' ;;
	application/vnd.apple.installer+xml) printf 'mpkg' ;;
	application/vnd.arastra.swi) printf 'swi' ;;
	application/vnd.audiograph) printf 'aep' ;;
	application/vnd.blueice.multipass) printf 'mpm' ;;
	application/vnd.bmi) printf 'bmi' ;;
	application/vnd.businessobjects) printf 'rep' ;;
	application/vnd.chemdraw+xml) printf 'cdxml' ;;
	application/vnd.chipnuts.karaoke-mmd) printf 'mmd' ;;
	application/vnd.cinderella) printf 'cdy' ;;
	application/vnd.claymore) printf 'cla' ;;
	application/vnd.clonk.c4group) printf 'c4d' ;;
	application/vnd.commonspace) printf 'csp' ;;
	application/vnd.contact.cmsg) printf 'cdbcmsg' ;;
	application/vnd.cosmocaller) printf 'cmc' ;;
	application/vnd.crick.clicker) printf 'clkx' ;;
	application/vnd.crick.clicker.keyboard) printf 'clkk' ;;
	application/vnd.crick.clicker.palette) printf 'clkp' ;;
	application/vnd.crick.clicker.template) printf 'clkt' ;;
	application/vnd.crick.clicker.wordbank) printf 'clkw' ;;
	application/vnd.criticaltools.wbs+xml) printf 'wbs' ;;
	application/vnd.ctc-posml) printf 'pml' ;;
	application/vnd.cups-ppd) printf 'ppd' ;;
	application/vnd.curl.car) printf 'car' ;;
	application/vnd.curl.pcurl) printf 'pcurl' ;;
	application/vnd.data-vision.rdz) printf 'rdz' ;;
	application/vnd.debian.binary-package) printf 'deb' ;;
	application/vnd.denovo.fcselayout-link) printf 'fe_launch' ;;
	application/vnd.dna) printf 'dna' ;;
	application/vnd.dolby.mlp) printf 'mlp' ;;
	application/vnd.dpgraph) printf 'dpg' ;;
	application/vnd.dreamfactory) printf 'dfac' ;;
	application/vnd.dynageo) printf 'geo' ;;
	application/vnd.ecowin.chart) printf 'mag' ;;
	application/vnd.enliven) printf 'nml' ;;
	application/vnd.epson.esf) printf 'esf' ;;
	application/vnd.epson.msf) printf 'msf' ;;
	application/vnd.epson.quickanime) printf 'qam' ;;
	application/vnd.epson.salt) printf 'slt' ;;
	application/vnd.epson.ssf) printf 'ssf' ;;
	application/vnd.eszigno3+xml) printf 'es3' ;;
	application/vnd.ezpix-album) printf 'ez2' ;;
	application/vnd.ezpix-package) printf 'ez3' ;;
	application/vnd.fdf) printf 'fdf' ;;
	application/vnd.fdsn.mseed) printf 'mseed' ;;
	application/vnd.fdsn.seed) printf 'dataless' ;;
	application/vnd.flographit) printf 'gph' ;;
	application/vnd.fluxtime.clip) printf 'ftc' ;;
	application/vnd.framemaker) printf 'book' ;;
	application/vnd.frogans.fnc) printf 'fnc' ;;
	application/vnd.frogans.ltf) printf 'ltf' ;;
	application/vnd.fsc.weblaunch) printf 'fsc' ;;
	application/vnd.fujitsu.oasys) printf 'oas' ;;
	application/vnd.fujitsu.oasys2) printf 'oa2' ;;
	application/vnd.fujitsu.oasys3) printf 'oa3' ;;
	application/vnd.fujitsu.oasysgp) printf 'fg5' ;;
	application/vnd.fujitsu.oasysprs) printf 'bh2' ;;
	application/vnd.fujixerox.ddd) printf 'ddd' ;;
	application/vnd.fujixerox.docuworks) printf 'xdw' ;;
	application/vnd.fujixerox.docuworks.binder) printf 'xbd' ;;
	application/vnd.fuzzysheet) printf 'fzs' ;;
	application/vnd.genomatix.tuxedo) printf 'txd' ;;
	application/vnd.geogebra.file) printf 'ggb' ;;
	application/vnd.geogebra.tool) printf 'ggt' ;;
	application/vnd.geometry-explorer) printf 'gex' ;;
	application/vnd.gerber) printf 'gbr' ;;
	application/vnd.gmx) printf 'gmx' ;;
	application/vnd.google-earth.kml+xml) printf 'kml' ;;
	application/vnd.google-earth.kmz) printf 'kmz' ;;
	application/vnd.grafeq) printf 'gqf' ;;
	application/vnd.groove-account) printf 'gac' ;;
	application/vnd.groove-help) printf 'ghf' ;;
	application/vnd.groove-identity-message) printf 'gim' ;;
	application/vnd.groove-injector) printf 'grv' ;;
	application/vnd.groove-tool-message) printf 'gtm' ;;
	application/vnd.groove-tool-template) printf 'tpl' ;;
	application/vnd.groove-vcard) printf 'vcg' ;;
	application/vnd.handheld-entertainment+xml) printf 'zmm' ;;
	application/vnd.hbci) printf 'hbci' ;;
	application/vnd.hhe.lesson-player) printf 'les' ;;
	application/vnd.hp-hpgl) printf 'hpgl' ;;
	application/vnd.hp-hpid) printf 'hpid' ;;
	application/vnd.hp-hps) printf 'hps' ;;
	application/vnd.hp-jlyt) printf 'jlt' ;;
	application/vnd.hp-pcl) printf 'pcl' ;;
	application/vnd.hp-pclxl) printf 'pclxl' ;;
	application/vnd.hydrostatix.sof-data) printf 'sfd-hdstx' ;;
	application/vnd.hzn-3d-crossword) printf 'x3d' ;;
	application/vnd.ibm.minipay) printf 'mpy' ;;
	application/vnd.ibm.modcap) printf 'afp' ;;
	application/vnd.ibm.rights-management) printf 'irm' ;;
	application/vnd.ibm.secure-container) printf 'sc' ;;
	application/vnd.iccprofile) printf 'icc' ;;
	application/vnd.igloader) printf 'igl' ;;
	application/vnd.immervision-ivp) printf 'ivp' ;;
	application/vnd.immervision-ivu) printf 'ivu' ;;
	application/vnd.intercon.formnet) printf 'xpw' ;;
	application/vnd.intu.qbo) printf 'qbo' ;;
	application/vnd.intu.qfx) printf 'qfx' ;;
	application/vnd.ipunplugged.rcprofile) printf 'rcprofile' ;;
	application/vnd.irepository.package+xml) printf 'irp' ;;
	application/vnd.is-xpr) printf 'xpr' ;;
	application/vnd.jam) printf 'jam' ;;
	application/vnd.jcp.javame.midlet-rms) printf 'rms' ;;
	application/vnd.jisp) printf 'jisp' ;;
	application/vnd.joost.joda-archive) printf 'joda' ;;
	application/vnd.kahootz) printf 'ktr' ;;
	application/vnd.kde.karbon) printf 'karbon' ;;
	application/vnd.kde.kchart) printf 'chrt' ;;
	application/vnd.kde.kformula) printf 'kfo' ;;
	application/vnd.kde.kivio) printf 'flw' ;;
	application/vnd.kde.kontour) printf 'kon' ;;
	application/vnd.kde.kpresenter) printf 'kpr' ;;
	application/vnd.kde.kspread) printf 'ksp' ;;
	application/vnd.kde.kword) printf 'kwd' ;;
	application/vnd.kenameaapp) printf 'htke' ;;
	application/vnd.kidspiration) printf 'kia' ;;
	application/vnd.kinar) printf 'kne' ;;
	application/vnd.koan) printf 'skd' ;;
	application/vnd.kodak-descriptor) printf 'sse' ;;
	application/vnd.llamagraphics.life-balance.desktop) printf 'lbd' ;;
	application/vnd.llamagraphics.life-balance.exchange+xml) printf 'lbe' ;;
	application/vnd.lotus-1-2-3) printf '123' ;;
	application/vnd.lotus-approach) printf 'apr' ;;
	application/vnd.lotus-freelance) printf 'pre' ;;
	application/vnd.lotus-notes) printf 'nsf' ;;
	application/vnd.lotus-organizer) printf 'org' ;;
	application/vnd.lotus-screencam) printf 'scm' ;;
	application/vnd.lotus-wordpro) printf 'lwp' ;;
	application/vnd.macports.portpkg) printf 'portpkg' ;;
	application/vnd.mcd) printf 'mcd' ;;
	application/vnd.medcalcdata) printf 'mc1' ;;
	application/vnd.mediastation.cdkey) printf 'cdkey' ;;
	application/vnd.mfer) printf 'mwf' ;;
	application/vnd.mfmp) printf 'mfm' ;;
	application/vnd.micrografx.flo) printf 'flo' ;;
	application/vnd.micrografx.igx) printf 'igx' ;;
	application/vnd.mif) printf 'mif' ;;
	application/vnd.mobius.daf) printf 'daf' ;;
	application/vnd.mobius.dis) printf 'dis' ;;
	application/vnd.mobius.mbk) printf 'mbk' ;;
	application/vnd.mobius.mqy) printf 'mqy' ;;
	application/vnd.mobius.msl) printf 'msl' ;;
	application/vnd.mobius.plc) printf 'plc' ;;
	application/vnd.mobius.txf) printf 'txf' ;;
	application/vnd.mophun.application) printf 'mpn' ;;
	application/vnd.mophun.certificate) printf 'mpc' ;;
	application/vnd.mozilla.xul+xml) printf 'xul' ;;
	application/vnd.ms-artgalry) printf 'cil' ;;
	application/vnd.ms-cab-compressed) printf 'cab' ;;
	application/vnd.ms-excel) printf 'xla' ;;
	application/vnd.ms-excel.addin.macroenabled.12) printf 'xlam' ;;
	application/vnd.ms-excel.sheet.binary.macroenabled.12) printf 'xlsb' ;;
	application/vnd.ms-excel.sheet.macroenabled.12) printf 'xlsm' ;;
	application/vnd.ms-excel.template.macroenabled.12) printf 'xltm' ;;
	application/vnd.ms-fontobject) printf 'eot' ;;
	application/vnd.ms-htmlhelp) printf 'chm' ;;
	application/vnd.ms-ims) printf 'ims' ;;
	application/vnd.ms-lrm) printf 'lrm' ;;
	application/vnd.ms-outlook) printf 'msg' ;;
	application/vnd.ms-pki.seccat) printf 'cat' ;;
	application/vnd.ms-pki.stl) printf 'stl' ;;
	application/vnd.ms-powerpoint) printf 'pot' ;;
	application/vnd.ms-powerpoint.addin.macroenabled.12) printf 'ppam' ;;
	application/vnd.ms-powerpoint.presentation.macroenabled.12) printf 'pptm' ;;
	application/vnd.ms-powerpoint.slide.macroenabled.12) printf 'sldm' ;;
	application/vnd.ms-powerpoint.slideshow.macroenabled.12) printf 'ppsm' ;;
	application/vnd.ms-powerpoint.template.macroenabled.12) printf 'potm' ;;
	application/vnd.ms-project) printf 'mpp' ;;
	application/vnd.ms-word.document.macroenabled.12) printf 'docm' ;;
	application/vnd.ms-word.template.macroenabled.12) printf 'dotm' ;;
	application/vnd.ms-works) printf 'wcm' ;;
	application/vnd.ms-wpl) printf 'wpl' ;;
	application/vnd.ms-xpsdocument) printf 'xps' ;;
	application/vnd.mseq) printf 'mseq' ;;
	application/vnd.musician) printf 'mus' ;;
	application/vnd.muvee.style) printf 'msty' ;;
	application/vnd.neurolanguage.nlu) printf 'nlu' ;;
	application/vnd.noblenet-directory) printf 'nnd' ;;
	application/vnd.noblenet-sealer) printf 'nns' ;;
	application/vnd.noblenet-web) printf 'nnw' ;;
	application/vnd.nokia.n-gage.data) printf 'ngdat' ;;
	application/vnd.nokia.n-gage.symbian.install) printf 'n-gage' ;;
	application/vnd.nokia.radio-preset) printf 'rpst' ;;
	application/vnd.nokia.radio-presets) printf 'rpss' ;;
	application/vnd.novadigm.edm) printf 'edm' ;;
	application/vnd.novadigm.edx) printf 'edx' ;;
	application/vnd.novadigm.ext) printf 'ext' ;;
	application/vnd.oasis.opendocument.chart) printf 'odc' ;;
	application/vnd.oasis.opendocument.chart-template) printf 'otc' ;;
	application/vnd.oasis.opendocument.database) printf 'odb' ;;
	application/vnd.oasis.opendocument.formula) printf 'odf' ;;
	application/vnd.oasis.opendocument.formula-template) printf 'odft' ;;
	application/vnd.oasis.opendocument.graphics) printf 'odg' ;;
	application/vnd.oasis.opendocument.graphics-template) printf 'otg' ;;
	application/vnd.oasis.opendocument.image) printf 'odi' ;;
	application/vnd.oasis.opendocument.image-template) printf 'oti' ;;
	application/vnd.oasis.opendocument.presentation) printf 'odp' ;;
	application/vnd.oasis.opendocument.presentation-template) printf 'otp' ;;
	application/vnd.oasis.opendocument.spreadsheet) printf 'ods' ;;
	application/vnd.oasis.opendocument.spreadsheet-template) printf 'ots' ;;
	application/vnd.oasis.opendocument.text) printf 'odt' ;;
	application/vnd.oasis.opendocument.text-master) printf 'otm' ;;
	application/vnd.oasis.opendocument.text-template) printf 'ott' ;;
	application/vnd.oasis.opendocument.text-web) printf 'oth' ;;
	application/vnd.olpc-sugar) printf 'xo' ;;
	application/vnd.oma.dd2+xml) printf 'dd2' ;;
	application/vnd.openofficeorg.extension) printf 'oxt' ;;
	application/vnd.openxmlformats-officedocument.presentationml.presentation) printf 'pptx' ;;
	application/vnd.openxmlformats-officedocument.presentationml.slide) printf 'sldx' ;;
	application/vnd.openxmlformats-officedocument.presentationml.slideshow) printf 'ppsx' ;;
	application/vnd.openxmlformats-officedocument.presentationml.template) printf 'potx' ;;
	application/vnd.openxmlformats-officedocument.spreadsheetml.sheet) printf 'xlsx' ;;
	application/vnd.openxmlformats-officedocument.spreadsheetml.template) printf 'xltx' ;;
	application/vnd.openxmlformats-officedocument.wordprocessingml.document) printf 'docx' ;;
	application/vnd.openxmlformats-officedocument.wordprocessingml.template) printf 'dotx' ;;
	application/vnd.osgi.dp) printf 'dp' ;;
	application/vnd.palm) printf 'oprc' ;;
	application/vnd.pg.format) printf 'str' ;;
	application/vnd.pg.osasli) printf 'ei6' ;;
	application/vnd.picsel) printf 'efif' ;;
	application/vnd.pocketlearn) printf 'plf' ;;
	application/vnd.powerbuilder6) printf 'pbd' ;;
	application/vnd.previewsystems.box) printf 'box' ;;
	application/vnd.proteus.magazine) printf 'mgz' ;;
	application/vnd.publishare-delta-tree) printf 'qps' ;;
	application/vnd.pvi.ptid1) printf 'ptid' ;;
	application/vnd.quark.quarkxpress) printf 'qwd' ;;
	application/vnd.rar) printf 'rar' ;;
	application/vnd.recordare.musicxml) printf 'mxl' ;;
	application/vnd.recordare.musicxml+xml) printf 'musicxml' ;;
	application/vnd.rim.cod) printf 'cod' ;;
	application/vnd.rn-realmedia) printf 'rm' ;;
	application/vnd.route66.link66+xml) printf 'link66' ;;
	application/vnd.seemail) printf 'see' ;;
	application/vnd.sema) printf 'sema' ;;
	application/vnd.semd) printf 'semd' ;;
	application/vnd.semf) printf 'semf' ;;
	application/vnd.shana.informed.formdata) printf 'ifm' ;;
	application/vnd.shana.informed.formtemplate) printf 'itp' ;;
	application/vnd.shana.informed.interchange) printf 'iif' ;;
	application/vnd.shana.informed.package) printf 'ipk' ;;
	application/vnd.simtech-mindmapper) printf 'twd' ;;
	application/vnd.smaf) printf 'mmf' ;;
	application/vnd.smart.teacher) printf 'teacher' ;;
	application/vnd.solent.sdkm+xml) printf 'sdkd' ;;
	application/vnd.spotfire.dxp) printf 'dxp' ;;
	application/vnd.spotfire.sfs) printf 'sfs' ;;
	application/vnd.sqlite3) printf 'db' ;;
	application/vnd.stardivision.calc) printf 'sdc' ;;
	application/vnd.stardivision.draw) printf 'sda' ;;
	application/vnd.stardivision.impress) printf 'sdd' ;;
	application/vnd.stardivision.math) printf 'smf' ;;
	application/vnd.stardivision.writer) printf 'sdw' ;;
	application/vnd.stardivision.writer-global) printf 'sgl' ;;
	application/vnd.sun.xml.calc) printf 'sxc' ;;
	application/vnd.sun.xml.calc.template) printf 'stc' ;;
	application/vnd.sun.xml.draw) printf 'sxd' ;;
	application/vnd.sun.xml.draw.template) printf 'std' ;;
	application/vnd.sun.xml.impress) printf 'sxi' ;;
	application/vnd.sun.xml.impress.template) printf 'sti' ;;
	application/vnd.sun.xml.math) printf 'sxm' ;;
	application/vnd.sun.xml.writer) printf 'sxw' ;;
	application/vnd.sun.xml.writer.global) printf 'sxg' ;;
	application/vnd.sun.xml.writer.template) printf 'stw' ;;
	application/vnd.sus-calendar) printf 'sus' ;;
	application/vnd.svd) printf 'svd' ;;
	application/vnd.symbian.install) printf 'sis' ;;
	application/vnd.syncml+xml) printf 'xsm' ;;
	application/vnd.syncml.dm+wbxml) printf 'bdm' ;;
	application/vnd.syncml.dm+xml) printf 'xdm' ;;
	application/vnd.tao.intent-module-archive) printf 'tao' ;;
	application/vnd.tmobile-livetv) printf 'tmo' ;;
	application/vnd.trid.tpt) printf 'tpt' ;;
	application/vnd.triscape.mxs) printf 'mxs' ;;
	application/vnd.trueapp) printf 'tra' ;;
	application/vnd.ufdl) printf 'ufd' ;;
	application/vnd.uiq.theme) printf 'utz' ;;
	application/vnd.umajin) printf 'umj' ;;
	application/vnd.unity) printf 'unityweb' ;;
	application/vnd.uoml+xml) printf 'uoml' ;;
	application/vnd.vcx) printf 'vcx' ;;
	application/vnd.visio) printf 'vsd' ;;
	application/vnd.visionary) printf 'vis' ;;
	application/vnd.vsf) printf 'vsf' ;;
	application/vnd.wap.sic) printf 'sic' ;;
	application/vnd.wap.slc) printf 'slc' ;;
	application/vnd.wap.wbxml) printf 'wbxml' ;;
	application/vnd.wap.wmlc) printf 'wmlc' ;;
	application/vnd.wap.wmlscriptc) printf 'wmlsc' ;;
	application/vnd.webturbo) printf 'wtb' ;;
	application/vnd.wordperfect) printf 'wpd' ;;
	application/vnd.wqd) printf 'wqd' ;;
	application/vnd.wt.stf) printf 'stf' ;;
	application/vnd.xara) printf 'xar' ;;
	application/vnd.xfdl) printf 'xfdl' ;;
	application/vnd.yamaha.hv-dic) printf 'hvd' ;;
	application/vnd.yamaha.hv-script) printf 'hvs' ;;
	application/vnd.yamaha.hv-voice) printf 'hvp' ;;
	application/vnd.yamaha.openscoreformat) printf 'osf' ;;
	application/vnd.yamaha.openscoreformat.osfpvg+xml) printf 'osfpvg' ;;
	application/vnd.yamaha.smaf-audio) printf 'saf' ;;
	application/vnd.yamaha.smaf-phrase) printf 'spf' ;;
	application/vnd.yellowriver-custom-menu) printf 'cmp' ;;
	application/vnd.zul) printf 'zir' ;;
	application/vnd.zzazz.deck+xml) printf 'zaz' ;;
	application/voicexml+xml) printf 'vxml' ;;
	application/wasm) printf 'wasm' ;;
	application/winhlp) printf 'hlp' ;;
	application/wsdl+xml) printf 'wsdl' ;;
	application/wspolicy+xml) printf 'wspolicy' ;;
	application/x-7z-compressed) printf '7z' ;;
	application/x-abiword) printf 'abw' ;;
	application/x-ace-compressed) printf 'ace' ;;
	application/x-authorware-bin) printf 'aab' ;;
	application/x-authorware-map) printf 'aam' ;;
	application/x-authorware-seg) printf 'aas' ;;
	application/x-bcpio) printf 'bcpio' ;;
	application/x-bittorrent) printf 'torrent' ;;
	application/x-bzip) printf 'bz' ;;
	application/x-bzip2) printf 'boz' ;;
	application/x-cdlink) printf 'vcd' ;;
	application/x-chat) printf 'chat' ;;
	application/x-chess-pgn) printf 'pgn' ;;
	application/x-cpio) printf 'cpio' ;;
	application/x-csh) printf 'csh' ;;
	application/x-debian-package) printf 'deb' ;;
	application/x-director) printf 'cct' ;;
	application/x-doom) printf 'wad' ;;
	application/x-dtbncx+xml) printf 'ncx' ;;
	application/x-dtbook+xml) printf 'dtb' ;;
	application/x-dtbresource+xml) printf 'res' ;;
	application/x-dvi) printf 'dvi' ;;
	application/x-elf) printf 'elf' ;;
	application/x-font-bdf) printf 'bdf' ;;
	application/x-font-ghostscript) printf 'gsf' ;;
	application/x-font-linux-psf) printf 'psf' ;;
	application/x-font-otf) printf 'otf' ;;
	application/x-font-pcf) printf 'pcf' ;;
	application/x-font-snf) printf 'snf' ;;
	application/x-font-ttf) printf 'ttc' ;;
	application/x-font-type1) printf 'afm' ;;
	application/x-futuresplash) printf 'spl' ;;
	application/x-gnumeric) printf 'gnumeric' ;;
	application/x-gtar) printf 'gtar' ;;
	application/x-gzip) printf 'gz' ;;
	application/x-hdf) printf 'hdf' ;;
	application/x-ipynb+json) printf 'ipynb' ;;
	application/x-iso9660-image) printf 'iso' ;;
	application/x-java-jnlp-file) printf 'jnlp' ;;
	application/x-killustrator) printf 'kil' ;;
	application/x-krita) printf 'kra' ;;
	application/x-latex) printf 'latex' ;;
	application/x-mobipocket-ebook) printf 'mobi' ;;
	application/x-ms-application) printf 'application' ;;
	application/x-ms-shortcut) printf 'lnk' ;;
	application/x-ms-wmd) printf 'wmd' ;;
	application/x-ms-wmz) printf 'wmz' ;;
	application/x-ms-xbap) printf 'xbap' ;;
	application/x-msaccess) printf 'mdb' ;;
	application/x-msbinder) printf 'obd' ;;
	application/x-mscardfile) printf 'crd' ;;
	application/x-msclip) printf 'clp' ;;
	application/x-msdownload) printf 'bat' ;;
	application/x-msmediaview) printf 'm13' ;;
	application/x-msmetafile) printf 'wmf' ;;
	application/x-msmoney) printf 'mny' ;;
	application/x-mspublisher) printf 'pub' ;;
	application/x-msschedule) printf 'scd' ;;
	application/x-msterminal) printf 'trm' ;;
	application/x-mswrite) printf 'wri' ;;
	application/x-netcdf) printf 'cdf' ;;
	application/x-perl) printf 'pm' ;;
	application/x-pkcs12) printf 'p12' ;;
	application/x-pkcs7-certificates) printf 'p7b' ;;
	application/x-pkcs7-certreqresp) printf 'p7r' ;;
	application/x-rar-compressed) printf 'rar' ;;
	application/x-redhat-package-manager) printf 'rpa' ;;
	application/x-rpm) printf 'rpm' ;;
	application/x-sh) printf 'sh' ;;
	application/x-shar) printf 'shar' ;;
	application/x-shellscript) printf 'sh' ;;
	application/x-shockwave-flash) printf 'swf' ;;
	application/x-silverlight-app) printf 'xap' ;;
	application/x-stuffit) printf 'sit' ;;
	application/x-stuffitx) printf 'sitx' ;;
	application/x-sv4cpio) printf 'sv4cpio' ;;
	application/x-sv4crc) printf 'sv4crc' ;;
	application/x-tar) printf 'tar' ;;
	application/x-tcl) printf 'tcl' ;;
	application/x-tex) printf 'tex' ;;
	application/x-tex-tfm) printf 'tfm' ;;
	application/x-texinfo) printf 'texi' ;;
	application/x-ustar) printf 'ustar' ;;
	application/x-wais-source) printf 'src' ;;
	application/x-x509-ca-cert) printf 'crt' ;;
	application/x-xfig) printf 'fig' ;;
	application/x-xpinstall) printf 'xpi' ;;
	application/x-xz) printf 'xz' ;;
	application/x-zip-compressed) printf 'zip' ;;
	application/xenc+xml) printf 'xenc' ;;
	application/xhtml+xml) printf 'xht' ;;
	application/xml) printf 'xml' ;;
	application/xml-dtd) printf 'dtd' ;;
	application/xop+xml) printf 'xop' ;;
	application/xslt+xml) printf 'xslt' ;;
	application/xspf+xml) printf 'xspf' ;;
	application/xv+xml) printf 'mxml' ;;
	application/yaml) printf 'yaml' ;;
	application/zip) printf 'zip' ;;
	application/zip-compressed) printf 'zip' ;;
	audio/3gpp2) printf '3g2' ;;
	audio/aac) printf 'aac' ;;
	audio/aacp) printf 'aacp' ;;
	audio/adpcm) printf 'adp' ;;
	audio/aiff) printf 'aiff' ;;
	audio/basic) printf 'au' ;;
	audio/flac) printf 'flac' ;;
	audio/midi) printf 'kar' ;;
	audio/mp4) printf 'mp4' ;;
	audio/mpeg) printf 'mp3' ;;
	audio/ogg) printf 'oga' ;;
	audio/opus) printf 'opus' ;;
	audio/vnd.digital-winds) printf 'eol' ;;
	audio/vnd.dts) printf 'dts' ;;
	audio/vnd.dts.hd) printf 'dtshd' ;;
	audio/vnd.lucent.voice) printf 'lvp' ;;
	audio/vnd.ms-playready.media.pya) printf 'pya' ;;
	audio/vnd.nuera.ecelp4800) printf 'ecelp4800' ;;
	audio/vnd.nuera.ecelp7470) printf 'ecelp7470' ;;
	audio/vnd.nuera.ecelp9600) printf 'ecelp9600' ;;
	audio/vnd.wav) printf 'wav' ;;
	audio/webm) printf 'weba' ;;
	audio/x-matroska) printf 'mka' ;;
	audio/x-mpegurl) printf 'm3u' ;;
	audio/x-ms-wax) printf 'wax' ;;
	audio/x-ms-wma) printf 'wma' ;;
	audio/x-pn-realaudio) printf 'ra' ;;
	audio/x-pn-realaudio-plugin) printf 'rmp' ;;
	chemical/x-cdx) printf 'cdx' ;;
	chemical/x-cif) printf 'cif' ;;
	chemical/x-cmdf) printf 'cmdf' ;;
	chemical/x-cml) printf 'cml' ;;
	chemical/x-csml) printf 'csml' ;;
	chemical/x-xyz) printf 'xyz' ;;
	font/otf) printf 'otf' ;;
	font/woff) printf 'woff' ;;
	font/woff2) printf 'woff2' ;;
	gcode) printf 'gcode' ;;
	image/avif) printf 'avif' ;;
	image/avif-sequence) printf 'avifs' ;;
	image/bmp) printf 'bmp' ;;
	image/cgm) printf 'cgm' ;;
	image/g3fax) printf 'g3' ;;
	image/gif) printf 'gif' ;;
	image/heic) printf 'heic' ;;
	image/heic-sequence) printf 'heics' ;;
	image/heif) printf 'heif' ;;
	image/heif-sequence) printf 'heifs' ;;
	image/ief) printf 'ief' ;;
	image/jpeg) printf 'jpg' ;;
	image/pjpeg) printf 'jpe' ;;
	image/png) printf 'png' ;;
	image/prs.btif) printf 'btif' ;;
	image/svg+xml) printf 'svg' ;;
	image/tiff) printf 'tif' ;;
	image/vnd.adobe.photoshop) printf 'psd' ;;
	image/vnd.djvu) printf 'djv' ;;
	image/vnd.dwg) printf 'dwg' ;;
	image/vnd.dxf) printf 'dxf' ;;
	image/vnd.fastbidsheet) printf 'fbs' ;;
	image/vnd.fpx) printf 'fpx' ;;
	image/vnd.fst) printf 'fst' ;;
	image/vnd.fujixerox.edmics-mmr) printf 'mmr' ;;
	image/vnd.fujixerox.edmics-rlc) printf 'rlc' ;;
	image/vnd.ms-modi) printf 'mdi' ;;
	image/vnd.net-fpx) printf 'npx' ;;
	image/vnd.wap.wbmp) printf 'wbmp' ;;
	image/vnd.xiff) printf 'xif' ;;
	image/webp) printf 'webp' ;;
	image/x-adobe-dng) printf 'dng' ;;
	image/x-canon-cr2) printf 'cr2' ;;
	image/x-canon-crw) printf 'crw' ;;
	image/x-cmu-raster) printf 'ras' ;;
	image/x-cmx) printf 'cmx' ;;
	image/x-epson-erf) printf 'erf' ;;
	image/x-freehand) printf 'fh' ;;
	image/x-fuji-raf) printf 'raf' ;;
	image/x-icns) printf 'icns' ;;
	image/x-icon) printf 'ico' ;;
	image/x-kodak-dcr) printf 'dcr' ;;
	image/x-kodak-k25) printf 'k25' ;;
	image/x-kodak-kdc) printf 'kdc' ;;
	image/x-minolta-mrw) printf 'mrw' ;;
	image/x-nikon-nef) printf 'nef' ;;
	image/x-olympus-orf) printf 'orf' ;;
	image/x-panasonic-raw) printf 'raw' ;;
	image/x-pcx) printf 'pcx' ;;
	image/x-pentax-pef) printf 'pef' ;;
	image/x-pict) printf 'pct' ;;
	image/x-portable-anymap) printf 'pnm' ;;
	image/x-portable-bitmap) printf 'pbm' ;;
	image/x-portable-graymap) printf 'pgm' ;;
	image/x-portable-pixmap) printf 'ppm' ;;
	image/x-rgb) printf 'rgb' ;;
	image/x-sigma-x3f) printf 'x3f' ;;
	image/x-sony-arw) printf 'arw' ;;
	image/x-sony-sr2) printf 'sr2' ;;
	image/x-sony-srf) printf 'srf' ;;
	image/x-xbitmap) printf 'xbm' ;;
	image/x-xpixmap) printf 'xpm' ;;
	image/x-xwindowdump) printf 'xwd' ;;
	message/rfc822) printf 'eml' ;;
	model/iges) printf 'iges' ;;
	model/mesh) printf 'mesh' ;;
	model/stl) printf 'stl' ;;
	model/vnd.dwf) printf 'dwf' ;;
	model/vnd.gdl) printf 'gdl' ;;
	model/vnd.gtw) printf 'gtw' ;;
	model/vnd.mts) printf 'mts' ;;
	model/vnd.vtu) printf 'vtu' ;;
	model/vrml) printf 'vrml' ;;
	test/mimetype) printf 'test' ;;
	text/calendar) printf 'ics' ;;
	text/css) printf 'css' ;;
	text/csv) printf 'csv' ;;
	text/html) printf 'htm' ;;
	text/javascript) printf 'js' ;;
	text/markdown) printf 'md' ;;
	text/mathml) printf 'mathml' ;;
	text/plain) printf 'txt' ;;
	text/prs.lines.tag) printf 'dsc' ;;
	text/richtext) printf 'rtx' ;;
	text/sgml) printf 'sgm' ;;
	text/tab-separated-values) printf 'tsv' ;;
	text/troff) printf 'man' ;;
	text/uri-list) printf 'uri' ;;
	text/vnd.curl) printf 'curl' ;;
	text/vnd.curl.dcurl) printf 'dcurl' ;;
	text/vnd.curl.mcurl) printf 'mcurl' ;;
	text/vnd.curl.scurl) printf 'scurl' ;;
	text/vnd.fly) printf 'fly' ;;
	text/vnd.fmi.flexstor) printf 'flx' ;;
	text/vnd.graphviz) printf 'gv' ;;
	text/vnd.in3d.3dml) printf '3dml' ;;
	text/vnd.in3d.spot) printf 'spot' ;;
	text/vnd.sun.j2me.app-descriptor) printf 'jad' ;;
	text/vnd.wap.si) printf 'si' ;;
	text/vnd.wap.sl) printf 'sl' ;;
	text/vnd.wap.wml) printf 'wml' ;;
	text/vnd.wap.wmlscript) printf 'wmls' ;;
	text/x-asm) printf 'asm' ;;
	text/x-c) printf 'c' ;;
	text/x-fortran) printf 'f' ;;
	text/x-java-source) printf 'java' ;;
	text/x-pascal) printf 'p' ;;
	text/x-python) printf 'py' ;;
	text/x-setext) printf 'etx' ;;
	text/x-shellscript) printf 'sh' ;;
	text/x-uuencode) printf 'uu' ;;
	text/x-vcalendar) printf 'vcs' ;;
	text/x-vcard) printf 'vcf' ;;
	video/3gpp) printf '3gp' ;;
	video/3gpp2) printf '3g2' ;;
	video/h261) printf 'h261' ;;
	video/h263) printf 'h263' ;;
	video/h264) printf 'h264' ;;
	video/jpeg) printf 'jpgv' ;;
	video/jpm) printf 'jpgm' ;;
	video/mj2) printf 'mj2' ;;
	video/mp2t) printf 'ts' ;;
	video/mp4) printf 'mp4' ;;
	video/mpeg) printf 'm1v' ;;
	video/ogg) printf 'ogv' ;;
	video/quicktime) printf 'mov' ;;
	video/vnd.fvt) printf 'fvt' ;;
	video/vnd.mpegurl) printf 'm4u' ;;
	video/vnd.ms-playready.media.pyv) printf 'pyv' ;;
	video/vnd.vivo) printf 'viv' ;;
	video/webm) printf 'webm' ;;
	video/x-f4v) printf 'f4v' ;;
	video/x-fli) printf 'fli' ;;
	video/x-flv) printf 'flv' ;;
	video/x-m4v) printf 'm4v' ;;
	video/x-matroska) printf 'mkv' ;;
	video/x-ms-asf) printf 'asf' ;;
	video/x-ms-wm) printf 'wm' ;;
	video/x-ms-wmv) printf 'wmv' ;;
	video/x-ms-wmx) printf 'wmx' ;;
	video/x-ms-wvx) printf 'wvx' ;;
	video/x-msvideo) printf 'avi' ;;
	video/x-sgi-movie) printf 'movie' ;;
	x-conference/x-cooltalk) printf 'ice' ;;
	*)
		return 1
		;;
	esac
}

# Canonical extension for a file's MIME type. Get_MIME_Extension <file>
Get_MIME_Extension() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	_MIME_Lookup_Ext "$MIME"
}

# Best matching extension for a file: exact MIME-table entry first, then
# x- normalized variants of the subtype, then the file's own extension when
# it already maps to the detected type, then a main-type default for
# extensionless files, then the original extension as the last resort.
# Get_MIME_Best_Extension <file>
Get_MIME_Best_Extension() {
	local File=$1
	local Mime Sub Variant OwnExt Ext Main Base

	Mime=$(Get_MIME_Type "$File") || return $?
	Mime=${Mime%%;*}
	Mime=${Mime,,}

	# 1) exact entry in the type -> extension table
	Ext=$(_MIME_Lookup_Ext "$Mime") && [ -n "$Ext" ] && {
		printf '%s' "$Ext"
		return 0
	}

	# 2) x- normalized variants of the subtype
	Sub=${Mime#*/}
	case "$Sub" in
	x-*)
		Variant="${Mime%%/*}/${Sub#x-}"
		Ext=$(_MIME_Lookup_Ext "$Variant") && [ -n "$Ext" ] && {
			printf '%s' "$Ext"
			return 0
		}
		;;
	*)
		Variant="${Mime%%/*}/x-${Sub}"
		Ext=$(_MIME_Lookup_Ext "$Variant") && [ -n "$Ext" ] && {
			printf '%s' "$Ext"
			return 0
		}
		;;
	esac

	# The file's own extension (same semantics as Get_File_Ext, kept inline
	# so this module stays standalone)
	Base=${File##*/}
	case "$Base" in
	.*.* | *.*.*) OwnExt=${Base##*.} ;;
	*) OwnExt='' ;;
	esac
	OwnExt=${OwnExt,,}

	# 3) the own extension, when it already maps to the detected type
	if [ -n "$OwnExt" ]; then
		Ext=$(Get_Extension_MIME "$OwnExt") || Ext=''
		if [ "$Ext" = "$Mime" ]; then
			printf '%s' "$OwnExt"
			return 0
		fi
	fi

	# 4) main-type default - only for files without any extension
	if [ -z "$OwnExt" ]; then
		Main=${Mime%%/*}
		case "$Main" in
		text)
			printf 'txt'
			return 0
			;;
		image)
			printf 'img'
			return 0
			;;
		audio)
			printf 'mp3'
			return 0
			;;
		video)
			printf 'mp4'
			return 0
			;;
		application)
			printf 'bin'
			return 0
			;;
		esac
	fi

	# 5) keep the original extension as the last resort
	if [ -n "$OwnExt" ]; then
		printf '%s' "$OwnExt"
		return 0
	fi

	return 1
}

# MIME type for an extension (no file needed). Get_Extension_MIME <ext>
Get_Extension_MIME() {
	local Ext=${1,,}
	Ext=${Ext#.}

	case "$Ext" in
	123) printf 'application/vnd.lotus-1-2-3' ;;
	3dml) printf 'text/vnd.in3d.3dml' ;;
	3g2) printf 'audio/3gpp2' ;;
	3ga) printf 'audio/mp4' ;;
	3gp) printf 'audio/mp4' ;;
	3gp2) printf 'audio/mp4' ;;
	3gpa) printf 'audio/mp4' ;;
	3gpp) printf 'audio/mp4' ;;
	3gpp2) printf 'audio/mp4' ;;
	7z) printf 'application/x-7z-compressed' ;;
	a) printf 'application/octet-stream' ;;
	aab) printf 'application/x-authorware-bin' ;;
	aac) printf 'audio/aac' ;;
	aacp) printf 'audio/aacp' ;;
	aam) printf 'application/x-authorware-map' ;;
	aas) printf 'application/x-authorware-seg' ;;
	abw) printf 'application/x-abiword' ;;
	abw.gz) printf 'application/x-abiword' ;;
	acc) printf 'application/vnd.americandynamics.acc' ;;
	ace) printf 'application/x-ace-compressed' ;;
	acu) printf 'application/vnd.acucobol' ;;
	acutc) printf 'application/vnd.acucorp' ;;
	adp) printf 'audio/adpcm' ;;
	aep) printf 'application/vnd.audiograph' ;;
	aff) printf 'audio/aiff' ;;
	afm) printf 'application/x-font-type1' ;;
	afp) printf 'application/vnd.ibm.modcap' ;;
	ai) printf 'application/postscript' ;;
	aif) printf 'audio/aiff' ;;
	aiff) printf 'audio/aiff' ;;
	air) printf 'application/vnd.adobe.air-application-installer-package+zip' ;;
	ami) printf 'application/vnd.amiga.ami' ;;
	apk) printf 'application/vnd.android.package-archive' ;;
	application) printf 'application/x-ms-application' ;;
	apr) printf 'application/vnd.lotus-approach' ;;
	arw) printf 'image/x-sony-arw' ;;
	asc) printf 'application/pgp-signature' ;;
	asf) printf 'video/x-ms-asf' ;;
	asm) printf 'text/x-asm' ;;
	aso) printf 'application/vnd.accpac.simply.aso' ;;
	asx) printf 'video/x-ms-asf' ;;
	atc) printf 'application/vnd.acucorp' ;;
	atom) printf 'application/atom+xml' ;;
	atomcat) printf 'application/atomcat+xml' ;;
	atomsvc) printf 'application/atomsvc+xml' ;;
	atx) printf 'application/vnd.antix.game-component' ;;
	au) printf 'audio/basic' ;;
	avi) printf 'video/x-msvideo' ;;
	avif) printf 'image/avif' ;;
	avifs) printf 'image/avif-sequence' ;;
	aw) printf 'application/applixware' ;;
	azf) printf 'application/vnd.airzip.filesecure.azf' ;;
	azs) printf 'application/vnd.airzip.filesecure.azs' ;;
	azw) printf 'application/vnd.amazon.ebook' ;;
	bash) printf 'text/x-shellscript' ;;
	bat) printf 'application/x-msdownload' ;;
	bcpio) printf 'application/x-bcpio' ;;
	bdf) printf 'application/x-font-bdf' ;;
	bdm) printf 'application/vnd.syncml.dm+wbxml' ;;
	bh2) printf 'application/vnd.fujitsu.oasysprs' ;;
	bin) printf 'application/octet-stream' ;;
	bmi) printf 'application/vnd.bmi' ;;
	bmp) printf 'image/bmp' ;;
	book) printf 'application/vnd.framemaker' ;;
	box) printf 'application/vnd.previewsystems.box' ;;
	boz) printf 'application/x-bzip2' ;;
	bpk) printf 'application/octet-stream' ;;
	btif) printf 'image/prs.btif' ;;
	bz) printf 'application/x-bzip' ;;
	bz2) printf 'application/x-bzip2' ;;
	c) printf 'text/x-c' ;;
	c4d) printf 'application/vnd.clonk.c4group' ;;
	c4f) printf 'application/vnd.clonk.c4group' ;;
	c4g) printf 'application/vnd.clonk.c4group' ;;
	c4p) printf 'application/vnd.clonk.c4group' ;;
	c4u) printf 'application/vnd.clonk.c4group' ;;
	cab) printf 'application/vnd.ms-cab-compressed' ;;
	car) printf 'application/vnd.curl.car' ;;
	cat) printf 'application/vnd.ms-pki.seccat' ;;
	cc) printf 'text/x-c' ;;
	cct) printf 'application/x-director' ;;
	ccxml) printf 'application/ccxml+xml' ;;
	cdbcmsg) printf 'application/vnd.contact.cmsg' ;;
	cdf) printf 'application/x-netcdf' ;;
	cdkey) printf 'application/vnd.mediastation.cdkey' ;;
	cdr) printf 'application/x-iso9660-image' ;;
	cdx) printf 'chemical/x-cdx' ;;
	cdxml) printf 'application/vnd.chemdraw+xml' ;;
	cdy) printf 'application/vnd.cinderella' ;;
	cer) printf 'application/pkix-cert' ;;
	cgm) printf 'image/cgm' ;;
	chat) printf 'application/x-chat' ;;
	chm) printf 'application/vnd.ms-htmlhelp' ;;
	chrt) printf 'application/vnd.kde.kchart' ;;
	cif) printf 'chemical/x-cif' ;;
	cii) printf 'application/vnd.anser-web-certificate-issue-initiation' ;;
	cil) printf 'application/vnd.ms-artgalry' ;;
	cla) printf 'application/vnd.claymore' ;;
	class) printf 'application/java-vm' ;;
	clkk) printf 'application/vnd.crick.clicker.keyboard' ;;
	clkp) printf 'application/vnd.crick.clicker.palette' ;;
	clkt) printf 'application/vnd.crick.clicker.template' ;;
	clkw) printf 'application/vnd.crick.clicker.wordbank' ;;
	clkx) printf 'application/vnd.crick.clicker' ;;
	clp) printf 'application/x-msclip' ;;
	cmc) printf 'application/vnd.cosmocaller' ;;
	cmdf) printf 'chemical/x-cmdf' ;;
	cml) printf 'chemical/x-cml' ;;
	cmp) printf 'application/vnd.yellowriver-custom-menu' ;;
	cmx) printf 'image/x-cmx' ;;
	cod) printf 'application/vnd.rim.cod' ;;
	com) printf 'application/x-msdownload' ;;
	conf) printf 'text/plain' ;;
	cpio) printf 'application/x-cpio' ;;
	cpp) printf 'text/x-c' ;;
	cpt) printf 'application/mac-compactpro' ;;
	cr2) printf 'image/x-canon-cr2' ;;
	crd) printf 'application/x-mscardfile' ;;
	crl) printf 'application/pkix-crl' ;;
	crt) printf 'application/x-x509-ca-cert' ;;
	crw) printf 'image/x-canon-crw' ;;
	csh) printf 'application/x-csh' ;;
	csml) printf 'chemical/x-csml' ;;
	csp) printf 'application/vnd.commonspace' ;;
	css) printf 'text/css' ;;
	cst) printf 'application/x-director' ;;
	csv) printf 'text/csv' ;;
	cu) printf 'application/cu-seeme' ;;
	curl) printf 'text/vnd.curl' ;;
	cww) printf 'application/prs.cww' ;;
	cxt) printf 'application/x-director' ;;
	cxx) printf 'text/x-c' ;;
	daf) printf 'application/vnd.mobius.daf' ;;
	dataless) printf 'application/vnd.fdsn.seed' ;;
	davmount) printf 'application/davmount+xml' ;;
	db) printf 'application/vnd.sqlite3' ;;
	db-shm) printf 'application/vnd.sqlite3' ;;
	db-wal) printf 'application/vnd.sqlite3' ;;
	dcr) printf 'application/x-director' ;;
	dcurl) printf 'text/vnd.curl.dcurl' ;;
	dd2) printf 'application/vnd.oma.dd2+xml' ;;
	ddd) printf 'application/vnd.fujixerox.ddd' ;;
	deb) printf 'application/vnd.debian.binary-package' ;;
	def) printf 'text/plain' ;;
	deploy) printf 'application/octet-stream' ;;
	der) printf 'application/x-x509-ca-cert' ;;
	dfac) printf 'application/vnd.dreamfactory' ;;
	dic) printf 'text/x-c' ;;
	diff) printf 'text/plain' ;;
	dir) printf 'application/x-director' ;;
	dis) printf 'application/vnd.mobius.dis' ;;
	dist) printf 'application/octet-stream' ;;
	distz) printf 'application/octet-stream' ;;
	djv) printf 'image/vnd.djvu' ;;
	djvu) printf 'image/vnd.djvu' ;;
	dll) printf 'application/x-msdownload' ;;
	dmg) printf 'application/octet-stream' ;;
	dms) printf 'application/octet-stream' ;;
	dna) printf 'application/vnd.dna' ;;
	dng) printf 'image/x-adobe-dng' ;;
	doc) printf 'application/msword' ;;
	docm) printf 'application/vnd.ms-word.document.macroenabled.12' ;;
	docx) printf 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ;;
	dot) printf 'application/msword' ;;
	dotm) printf 'application/vnd.ms-word.template.macroenabled.12' ;;
	dotx) printf 'application/vnd.openxmlformats-officedocument.wordprocessingml.template' ;;
	dp) printf 'application/vnd.osgi.dp' ;;
	dpg) printf 'application/vnd.dpgraph' ;;
	dsc) printf 'text/prs.lines.tag' ;;
	dtb) printf 'application/x-dtbook+xml' ;;
	dtd) printf 'application/xml-dtd' ;;
	dts) printf 'audio/vnd.dts' ;;
	dtshd) printf 'audio/vnd.dts.hd' ;;
	dump) printf 'application/octet-stream' ;;
	dvi) printf 'application/x-dvi' ;;
	dwf) printf 'model/vnd.dwf' ;;
	dwg) printf 'image/vnd.dwg' ;;
	dxf) printf 'image/vnd.dxf' ;;
	dxp) printf 'application/vnd.spotfire.dxp' ;;
	dxr) printf 'application/x-director' ;;
	ecelp4800) printf 'audio/vnd.nuera.ecelp4800' ;;
	ecelp7470) printf 'audio/vnd.nuera.ecelp7470' ;;
	ecelp9600) printf 'audio/vnd.nuera.ecelp9600' ;;
	ecma) printf 'application/ecmascript' ;;
	edm) printf 'application/vnd.novadigm.edm' ;;
	edx) printf 'application/vnd.novadigm.edx' ;;
	efif) printf 'application/vnd.picsel' ;;
	ei6) printf 'application/vnd.pg.osasli' ;;
	elc) printf 'application/octet-stream' ;;
	elf) printf 'application/x-elf' ;;
	eml) printf 'message/rfc822' ;;
	emma) printf 'application/emma+xml' ;;
	eol) printf 'audio/vnd.digital-winds' ;;
	eot) printf 'application/vnd.ms-fontobject' ;;
	eps) printf 'application/postscript' ;;
	epub) printf 'application/epub+zip' ;;
	erf) printf 'image/x-epson-erf' ;;
	es3) printf 'application/vnd.eszigno3+xml' ;;
	esf) printf 'application/vnd.epson.esf' ;;
	et3) printf 'application/vnd.eszigno3+xml' ;;
	etx) printf 'text/x-setext' ;;
	exe) printf 'application/x-msdownload' ;;
	ext) printf 'application/vnd.novadigm.ext' ;;
	ez) printf 'application/andrew-inset' ;;
	ez2) printf 'application/vnd.ezpix-album' ;;
	ez3) printf 'application/vnd.ezpix-package' ;;
	f) printf 'text/x-fortran' ;;
	f4v) printf 'video/x-f4v' ;;
	f77) printf 'text/x-fortran' ;;
	f90) printf 'text/x-fortran' ;;
	fbs) printf 'image/vnd.fastbidsheet' ;;
	fdf) printf 'application/vnd.fdf' ;;
	fe_launch) printf 'application/vnd.denovo.fcselayout-link' ;;
	fg5) printf 'application/vnd.fujitsu.oasysgp' ;;
	fgd) printf 'application/x-director' ;;
	fh) printf 'image/x-freehand' ;;
	fh4) printf 'image/x-freehand' ;;
	fh5) printf 'image/x-freehand' ;;
	fh7) printf 'image/x-freehand' ;;
	fhc) printf 'image/x-freehand' ;;
	fig) printf 'application/x-xfig' ;;
	flac) printf 'audio/flac' ;;
	fli) printf 'video/x-fli' ;;
	flo) printf 'application/vnd.micrografx.flo' ;;
	flv) printf 'video/x-flv' ;;
	flw) printf 'application/vnd.kde.kivio' ;;
	flx) printf 'text/vnd.fmi.flexstor' ;;
	fly) printf 'text/vnd.fly' ;;
	fm) printf 'application/vnd.framemaker' ;;
	fnc) printf 'application/vnd.frogans.fnc' ;;
	for) printf 'text/x-fortran' ;;
	fpx) printf 'image/vnd.fpx' ;;
	frame) printf 'application/vnd.framemaker' ;;
	fsc) printf 'application/vnd.fsc.weblaunch' ;;
	fst) printf 'image/vnd.fst' ;;
	ftc) printf 'application/vnd.fluxtime.clip' ;;
	fti) printf 'application/vnd.anser-web-funds-transfer-initiation' ;;
	fvt) printf 'video/vnd.fvt' ;;
	fzs) printf 'application/vnd.fuzzysheet' ;;
	g3) printf 'image/g3fax' ;;
	gac) printf 'application/vnd.groove-account' ;;
	gbr) printf 'application/vnd.gerber' ;;
	gcode) printf 'gcode' ;;
	gdl) printf 'model/vnd.gdl' ;;
	geo) printf 'application/vnd.dynageo' ;;
	gex) printf 'application/vnd.geometry-explorer' ;;
	ggb) printf 'application/vnd.geogebra.file' ;;
	ggt) printf 'application/vnd.geogebra.tool' ;;
	ghf) printf 'application/vnd.groove-help' ;;
	gif) printf 'image/gif' ;;
	gim) printf 'application/vnd.groove-identity-message' ;;
	gmx) printf 'application/vnd.gmx' ;;
	gnumeric) printf 'application/x-gnumeric' ;;
	gph) printf 'application/vnd.flographit' ;;
	gqf) printf 'application/vnd.grafeq' ;;
	gqs) printf 'application/vnd.grafeq' ;;
	gram) printf 'application/srgs' ;;
	gre) printf 'application/vnd.geometry-explorer' ;;
	grv) printf 'application/vnd.groove-injector' ;;
	grxml) printf 'application/srgs+xml' ;;
	gsf) printf 'application/x-font-ghostscript' ;;
	gtar) printf 'application/x-gtar' ;;
	gtm) printf 'application/vnd.groove-tool-message' ;;
	gtw) printf 'model/vnd.gtw' ;;
	gv) printf 'text/vnd.graphviz' ;;
	gz) printf 'application/gzip' ;;
	h) printf 'text/x-c' ;;
	h261) printf 'video/h261' ;;
	h263) printf 'video/h263' ;;
	h264) printf 'video/h264' ;;
	hbci) printf 'application/vnd.hbci' ;;
	hdf) printf 'application/x-hdf' ;;
	heic) printf 'image/heic' ;;
	heics) printf 'image/heic-sequence' ;;
	heif) printf 'image/heif' ;;
	heifs) printf 'image/heif-sequence' ;;
	hh) printf 'text/x-c' ;;
	hif) printf 'image/heic' ;;
	hlp) printf 'application/winhlp' ;;
	hpgl) printf 'application/vnd.hp-hpgl' ;;
	hpid) printf 'application/vnd.hp-hpid' ;;
	hps) printf 'application/vnd.hp-hps' ;;
	hqx) printf 'application/mac-binhex40' ;;
	htke) printf 'application/vnd.kenameaapp' ;;
	htm) printf 'text/html' ;;
	html) printf 'text/html' ;;
	hvd) printf 'application/vnd.yamaha.hv-dic' ;;
	hvp) printf 'application/vnd.yamaha.hv-voice' ;;
	hvs) printf 'application/vnd.yamaha.hv-script' ;;
	icc) printf 'application/vnd.iccprofile' ;;
	ice) printf 'x-conference/x-cooltalk' ;;
	icm) printf 'application/vnd.iccprofile' ;;
	icns) printf 'image/x-icns' ;;
	ico) printf 'image/x-icon' ;;
	ics) printf 'text/calendar' ;;
	ief) printf 'image/ief' ;;
	ifb) printf 'text/calendar' ;;
	ifm) printf 'application/vnd.shana.informed.formdata' ;;
	iges) printf 'model/iges' ;;
	igl) printf 'application/vnd.igloader' ;;
	igs) printf 'model/iges' ;;
	igx) printf 'application/vnd.micrografx.igx' ;;
	iif) printf 'application/vnd.shana.informed.interchange' ;;
	imp) printf 'application/vnd.accpac.simply.imp' ;;
	ims) printf 'application/vnd.ms-ims' ;;
	in) printf 'text/plain' ;;
	inc) printf 'text/x-pascal' ;;
	ipk) printf 'application/vnd.shana.informed.package' ;;
	ipynb) printf 'application/x-ipynb+json' ;;
	irm) printf 'application/vnd.ibm.rights-management' ;;
	irp) printf 'application/vnd.irepository.package+xml' ;;
	iso) printf 'application/x-iso9660-image' ;;
	isoimg) printf 'application/x-iso9660-image' ;;
	itp) printf 'application/vnd.shana.informed.formtemplate' ;;
	ivp) printf 'application/vnd.immervision-ivp' ;;
	ivu) printf 'application/vnd.immervision-ivu' ;;
	jad) printf 'text/vnd.sun.j2me.app-descriptor' ;;
	jam) printf 'application/vnd.jam' ;;
	jar) printf 'application/java-archive' ;;
	java) printf 'text/x-java-source' ;;
	jfi) printf 'image/pjpeg' ;;
	jfif) printf 'image/jpeg' ;;
	jfif-tbnl) printf 'image/jpeg' ;;
	jif) printf 'image/jpeg' ;;
	jisp) printf 'application/vnd.jisp' ;;
	jlt) printf 'application/vnd.hp-jlyt' ;;
	jnlp) printf 'application/x-java-jnlp-file' ;;
	joda) printf 'application/vnd.joost.joda-archive' ;;
	jpe) printf 'image/jpeg' ;;
	jpeg) printf 'image/jpeg' ;;
	jpg) printf 'image/jpeg' ;;
	jpgm) printf 'video/jpm' ;;
	jpgv) printf 'video/jpeg' ;;
	jpm) printf 'video/jpm' ;;
	js) printf 'text/javascript' ;;
	json) printf 'application/json' ;;
	k25) printf 'image/x-kodak-k25' ;;
	kar) printf 'audio/midi' ;;
	karbon) printf 'application/vnd.kde.karbon' ;;
	kdc) printf 'image/x-kodak-kdc' ;;
	kfo) printf 'application/vnd.kde.kformula' ;;
	kia) printf 'application/vnd.kidspiration' ;;
	kil) printf 'application/x-killustrator' ;;
	kml) printf 'application/vnd.google-earth.kml+xml' ;;
	kmz) printf 'application/vnd.google-earth.kmz' ;;
	kne) printf 'application/vnd.kinar' ;;
	knp) printf 'application/vnd.kinar' ;;
	kon) printf 'application/vnd.kde.kontour' ;;
	kpr) printf 'application/vnd.kde.kpresenter' ;;
	kpt) printf 'application/vnd.kde.kpresenter' ;;
	kra) printf 'application/x-krita' ;;
	krz) printf 'application/x-krita' ;;
	ksh) printf 'text/plain' ;;
	ksp) printf 'application/vnd.kde.kspread' ;;
	ktr) printf 'application/vnd.kahootz' ;;
	ktz) printf 'application/vnd.kahootz' ;;
	kwd) printf 'application/vnd.kde.kword' ;;
	kwt) printf 'application/vnd.kde.kword' ;;
	latex) printf 'application/x-latex' ;;
	lbd) printf 'application/vnd.llamagraphics.life-balance.desktop' ;;
	lbe) printf 'application/vnd.llamagraphics.life-balance.exchange+xml' ;;
	les) printf 'application/vnd.hhe.lesson-player' ;;
	lha) printf 'application/octet-stream' ;;
	link66) printf 'application/vnd.route66.link66+xml' ;;
	list) printf 'text/plain' ;;
	list3820) printf 'application/vnd.ibm.modcap' ;;
	listafp) printf 'application/vnd.ibm.modcap' ;;
	lnk) printf 'application/x-ms-shortcut' ;;
	log) printf 'text/plain' ;;
	lostxml) printf 'application/lost+xml' ;;
	lrf) printf 'application/octet-stream' ;;
	lrm) printf 'application/vnd.ms-lrm' ;;
	ltf) printf 'application/vnd.frogans.ltf' ;;
	lvp) printf 'audio/vnd.lucent.voice' ;;
	lwp) printf 'application/vnd.lotus-wordpro' ;;
	lzh) printf 'application/octet-stream' ;;
	m13) printf 'application/x-msmediaview' ;;
	m14) printf 'application/x-msmediaview' ;;
	m1v) printf 'video/mpeg' ;;
	m2a) printf 'audio/mpeg' ;;
	m2v) printf 'video/mpeg' ;;
	m3a) printf 'audio/mpeg' ;;
	m3u) printf 'audio/x-mpegurl' ;;
	m4a) printf 'audio/aac' ;;
	m4b) printf 'audio/mp4' ;;
	m4p) printf 'audio/mp4' ;;
	m4r) printf 'audio/mp4' ;;
	m4u) printf 'video/vnd.mpegurl' ;;
	m4v) printf 'audio/mp4' ;;
	ma) printf 'application/mathematica' ;;
	mag) printf 'application/vnd.ecowin.chart' ;;
	maker) printf 'application/vnd.framemaker' ;;
	man) printf 'text/troff' ;;
	markdn) printf 'text/markdown' ;;
	markdown) printf 'text/markdown' ;;
	mathml) printf 'application/mathml+xml' ;;
	mb) printf 'application/mathematica' ;;
	mbk) printf 'application/vnd.mobius.mbk' ;;
	mbox) printf 'application/mbox' ;;
	mc1) printf 'application/vnd.medcalcdata' ;;
	mcd) printf 'application/vnd.mcd' ;;
	mcurl) printf 'text/vnd.curl.mcurl' ;;
	md) printf 'text/markdown' ;;
	mdb) printf 'application/x-msaccess' ;;
	mdi) printf 'image/vnd.ms-modi' ;;
	mdown) printf 'text/markdown' ;;
	me) printf 'text/troff' ;;
	mesh) printf 'model/mesh' ;;
	mfm) printf 'application/vnd.mfmp' ;;
	mgz) printf 'application/vnd.proteus.magazine' ;;
	mht) printf 'message/rfc822' ;;
	mhtml) printf 'message/rfc822' ;;
	mid) printf 'audio/midi' ;;
	midi) printf 'audio/midi' ;;
	mif) printf 'application/vnd.mif' ;;
	mime) printf 'message/rfc822' ;;
	mj2) printf 'video/mj2' ;;
	mjp2) printf 'video/mj2' ;;
	mka) printf 'audio/x-matroska' ;;
	mkv) printf 'video/x-matroska' ;;
	mlp) printf 'application/vnd.dolby.mlp' ;;
	mmd) printf 'application/vnd.chipnuts.karaoke-mmd' ;;
	mmf) printf 'application/vnd.smaf' ;;
	mml) printf 'application/mathml+xml' ;;
	mmr) printf 'image/vnd.fujixerox.edmics-mmr' ;;
	mny) printf 'application/x-msmoney' ;;
	mobi) printf 'application/x-mobipocket-ebook' ;;
	mov) printf 'video/quicktime' ;;
	movie) printf 'video/x-sgi-movie' ;;
	mp2) printf 'audio/mpeg' ;;
	mp2a) printf 'audio/mpeg' ;;
	mp3) printf 'audio/mpeg' ;;
	mp4) printf 'audio/mp4' ;;
	mp4s) printf 'application/mp4' ;;
	mp4v) printf 'audio/mp4' ;;
	mpa) printf 'video/mpeg' ;;
	mpc) printf 'application/vnd.mophun.certificate' ;;
	mpe) printf 'video/mpeg' ;;
	mpeg) printf 'video/mpeg' ;;
	mpg) printf 'video/mpeg' ;;
	mpg4) printf 'video/mp4' ;;
	mpga) printf 'audio/mpeg' ;;
	mpkg) printf 'application/vnd.apple.installer+xml' ;;
	mpm) printf 'application/vnd.blueice.multipass' ;;
	mpn) printf 'application/vnd.mophun.application' ;;
	mpp) printf 'application/vnd.ms-project' ;;
	mpt) printf 'application/vnd.ms-project' ;;
	mpy) printf 'application/vnd.ibm.minipay' ;;
	mqy) printf 'application/vnd.mobius.mqy' ;;
	mrc) printf 'application/marc' ;;
	mrw) printf 'image/x-minolta-mrw' ;;
	ms) printf 'text/troff' ;;
	mscml) printf 'application/mediaservercontrol+xml' ;;
	mseed) printf 'application/vnd.fdsn.mseed' ;;
	mseq) printf 'application/vnd.mseq' ;;
	msf) printf 'application/vnd.epson.msf' ;;
	msg) printf 'application/vnd.ms-outlook' ;;
	msh) printf 'model/mesh' ;;
	msi) printf 'application/x-msdownload' ;;
	msl) printf 'application/vnd.mobius.msl' ;;
	msty) printf 'application/vnd.muvee.style' ;;
	mts) printf 'model/vnd.mts' ;;
	mus) printf 'application/vnd.musician' ;;
	musicxml) printf 'application/vnd.recordare.musicxml+xml' ;;
	mvb) printf 'application/x-msmediaview' ;;
	mwf) printf 'application/vnd.mfer' ;;
	mxf) printf 'application/mxf' ;;
	mxl) printf 'application/vnd.recordare.musicxml' ;;
	mxml) printf 'application/xv+xml' ;;
	mxs) printf 'application/vnd.triscape.mxs' ;;
	mxu) printf 'video/vnd.mpegurl' ;;
	n-gage) printf 'application/vnd.nokia.n-gage.symbian.install' ;;
	nb) printf 'application/mathematica' ;;
	nc) printf 'application/x-netcdf' ;;
	ncx) printf 'application/x-dtbncx+xml' ;;
	nef) printf 'image/x-nikon-nef' ;;
	ngdat) printf 'application/vnd.nokia.n-gage.data' ;;
	nlu) printf 'application/vnd.neurolanguage.nlu' ;;
	nml) printf 'application/vnd.enliven' ;;
	nnd) printf 'application/vnd.noblenet-directory' ;;
	nns) printf 'application/vnd.noblenet-sealer' ;;
	nnw) printf 'application/vnd.noblenet-web' ;;
	npx) printf 'image/vnd.net-fpx' ;;
	nsf) printf 'application/vnd.lotus-notes' ;;
	nws) printf 'message/rfc822' ;;
	o) printf 'application/octet-stream' ;;
	oa2) printf 'application/vnd.fujitsu.oasys2' ;;
	oa3) printf 'application/vnd.fujitsu.oasys3' ;;
	oas) printf 'application/vnd.fujitsu.oasys' ;;
	obd) printf 'application/x-msbinder' ;;
	obj) printf 'application/octet-stream' ;;
	oda) printf 'application/oda' ;;
	odb) printf 'application/vnd.oasis.opendocument.database' ;;
	odc) printf 'application/vnd.oasis.opendocument.chart' ;;
	odf) printf 'application/vnd.oasis.opendocument.formula' ;;
	odft) printf 'application/vnd.oasis.opendocument.formula-template' ;;
	odg) printf 'application/vnd.oasis.opendocument.graphics' ;;
	odi) printf 'application/vnd.oasis.opendocument.image' ;;
	odp) printf 'application/vnd.oasis.opendocument.presentation' ;;
	ods) printf 'application/vnd.oasis.opendocument.spreadsheet' ;;
	odt) printf 'application/vnd.oasis.opendocument.text' ;;
	oga) printf 'audio/ogg' ;;
	ogg) printf 'audio/ogg' ;;
	ogv) printf 'video/ogg' ;;
	ogx) printf 'application/ogg' ;;
	onepkg) printf 'application/onenote' ;;
	onetmp) printf 'application/onenote' ;;
	onetoc) printf 'application/onenote' ;;
	onetoc2) printf 'application/onenote' ;;
	opf) printf 'application/oebps-package+xml' ;;
	oprc) printf 'application/vnd.palm' ;;
	opus) printf 'audio/opus' ;;
	orf) printf 'image/x-olympus-orf' ;;
	org) printf 'application/vnd.lotus-organizer' ;;
	osf) printf 'application/vnd.yamaha.openscoreformat' ;;
	osfpvg) printf 'application/vnd.yamaha.openscoreformat.osfpvg+xml' ;;
	otc) printf 'application/vnd.oasis.opendocument.chart-template' ;;
	otf) printf 'application/x-font-otf' ;;
	otg) printf 'application/vnd.oasis.opendocument.graphics-template' ;;
	oth) printf 'application/vnd.oasis.opendocument.text-web' ;;
	oti) printf 'application/vnd.oasis.opendocument.image-template' ;;
	otm) printf 'application/vnd.oasis.opendocument.text-master' ;;
	otp) printf 'application/vnd.oasis.opendocument.presentation-template' ;;
	ots) printf 'application/vnd.oasis.opendocument.spreadsheet-template' ;;
	ott) printf 'application/vnd.oasis.opendocument.text-template' ;;
	oxt) printf 'application/vnd.openofficeorg.extension' ;;
	p) printf 'text/x-pascal' ;;
	p10) printf 'application/pkcs10' ;;
	p12) printf 'application/x-pkcs12' ;;
	p7b) printf 'application/x-pkcs7-certificates' ;;
	p7c) printf 'application/pkcs7-mime' ;;
	p7m) printf 'application/pkcs7-mime' ;;
	p7r) printf 'application/x-pkcs7-certreqresp' ;;
	p7s) printf 'application/pkcs7-signature' ;;
	pas) printf 'text/x-pascal' ;;
	pbd) printf 'application/vnd.powerbuilder6' ;;
	pbm) printf 'image/x-portable-bitmap' ;;
	pcf) printf 'application/x-font-pcf' ;;
	pcl) printf 'application/vnd.hp-pcl' ;;
	pclxl) printf 'application/vnd.hp-pclxl' ;;
	pct) printf 'image/x-pict' ;;
	pcurl) printf 'application/vnd.curl.pcurl' ;;
	pcx) printf 'image/x-pcx' ;;
	pdb) printf 'application/vnd.palm' ;;
	pdf) printf 'application/pdf' ;;
	pef) printf 'image/x-pentax-pef' ;;
	pfa) printf 'application/x-font-type1' ;;
	pfb) printf 'application/x-font-type1' ;;
	pfm) printf 'application/x-font-type1' ;;
	pfr) printf 'application/font-tdpfr' ;;
	pfx) printf 'application/x-pkcs12' ;;
	pgm) printf 'image/x-portable-graymap' ;;
	pgn) printf 'application/x-chess-pgn' ;;
	pgp) printf 'application/pgp-encrypted' ;;
	pic) printf 'image/x-pict' ;;
	pjpg) printf 'image/jpeg' ;;
	pkg) printf 'application/octet-stream' ;;
	pki) printf 'application/pkixcmp' ;;
	pkipath) printf 'application/pkix-pkipath' ;;
	pl) printf 'application/x-perl' ;;
	plb) printf 'application/vnd.3gpp.pic-bw-large' ;;
	plc) printf 'application/vnd.mobius.plc' ;;
	plf) printf 'application/vnd.pocketlearn' ;;
	pls) printf 'application/pls+xml' ;;
	pm) printf 'application/x-perl' ;;
	pml) printf 'application/vnd.ctc-posml' ;;
	png) printf 'image/png' ;;
	pnm) printf 'image/x-portable-anymap' ;;
	portpkg) printf 'application/vnd.macports.portpkg' ;;
	pot) printf 'application/vnd.ms-powerpoint' ;;
	potm) printf 'application/vnd.ms-powerpoint.template.macroenabled.12' ;;
	potx) printf 'application/vnd.openxmlformats-officedocument.presentationml.template' ;;
	pp) printf 'text/x-pascal' ;;
	ppa) printf 'application/vnd.ms-powerpoint' ;;
	ppam) printf 'application/vnd.ms-powerpoint.addin.macroenabled.12' ;;
	ppd) printf 'application/vnd.cups-ppd' ;;
	ppm) printf 'image/x-portable-pixmap' ;;
	pps) printf 'application/vnd.ms-powerpoint' ;;
	ppsm) printf 'application/vnd.ms-powerpoint.slideshow.macroenabled.12' ;;
	ppsx) printf 'application/vnd.openxmlformats-officedocument.presentationml.slideshow' ;;
	ppt) printf 'application/vnd.ms-powerpoint' ;;
	pptm) printf 'application/vnd.ms-powerpoint.presentation.macroenabled.12' ;;
	pptx) printf 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ;;
	pqa) printf 'application/vnd.palm' ;;
	prc) printf 'application/x-mobipocket-ebook' ;;
	pre) printf 'application/vnd.lotus-freelance' ;;
	prf) printf 'application/pics-rules' ;;
	prql) printf 'application/prql' ;;
	ps) printf 'application/postscript' ;;
	psb) printf 'application/vnd.3gpp.pic-bw-small' ;;
	psd) printf 'image/vnd.adobe.photoshop' ;;
	psf) printf 'application/x-font-linux-psf' ;;
	ptid) printf 'application/vnd.pvi.ptid1' ;;
	ptx) printf 'image/x-pentax-pef' ;;
	pub) printf 'application/x-mspublisher' ;;
	pvb) printf 'application/vnd.3gpp.pic-bw-var' ;;
	pwn) printf 'application/vnd.3m.post-it-notes' ;;
	pwz) printf 'application/vnd.ms-powerpoint' ;;
	py) printf 'text/x-python' ;;
	pya) printf 'audio/vnd.ms-playready.media.pya' ;;
	pyc) printf 'text/x-python' ;;
	pyd) printf 'text/x-python' ;;
	pyo) printf 'text/x-python' ;;
	pyv) printf 'video/vnd.ms-playready.media.pyv' ;;
	qam) printf 'application/vnd.epson.quickanime' ;;
	qbo) printf 'application/vnd.intu.qbo' ;;
	qfx) printf 'application/vnd.intu.qfx' ;;
	qps) printf 'application/vnd.publishare-delta-tree' ;;
	qt) printf 'video/quicktime' ;;
	qwd) printf 'application/vnd.quark.quarkxpress' ;;
	qwt) printf 'application/vnd.quark.quarkxpress' ;;
	qxb) printf 'application/vnd.quark.quarkxpress' ;;
	qxd) printf 'application/vnd.quark.quarkxpress' ;;
	qxl) printf 'application/vnd.quark.quarkxpress' ;;
	qxt) printf 'application/vnd.quark.quarkxpress' ;;
	ra) printf 'audio/x-pn-realaudio' ;;
	raf) printf 'image/x-fuji-raf' ;;
	ram) printf 'audio/x-pn-realaudio' ;;
	rar) printf 'application/vnd.rar' ;;
	ras) printf 'image/x-cmu-raster' ;;
	raw) printf 'image/x-panasonic-raw' ;;
	rcprofile) printf 'application/vnd.ipunplugged.rcprofile' ;;
	rdf) printf 'application/rdf+xml' ;;
	rdz) printf 'application/vnd.data-vision.rdz' ;;
	rep) printf 'application/vnd.businessobjects' ;;
	res) printf 'application/x-dtbresource+xml' ;;
	rgb) printf 'image/x-rgb' ;;
	rif) printf 'application/reginfo+xml' ;;
	rl) printf 'application/resource-lists+xml' ;;
	rlc) printf 'image/vnd.fujixerox.edmics-rlc' ;;
	rld) printf 'application/resource-lists-diff+xml' ;;
	rm) printf 'application/vnd.rn-realmedia' ;;
	rmi) printf 'audio/midi' ;;
	rmp) printf 'audio/x-pn-realaudio-plugin' ;;
	rms) printf 'application/vnd.jcp.javame.midlet-rms' ;;
	rnc) printf 'application/relax-ng-compact-syntax' ;;
	roff) printf 'text/troff' ;;
	rpa) printf 'application/x-redhat-package-manager' ;;
	rpm) printf 'application/x-rpm' ;;
	rpss) printf 'application/vnd.nokia.radio-presets' ;;
	rpst) printf 'application/vnd.nokia.radio-preset' ;;
	rq) printf 'application/sparql-query' ;;
	rs) printf 'application/rls-services+xml' ;;
	rsd) printf 'application/rsd+xml' ;;
	rss) printf 'application/rss+xml' ;;
	rtf) printf 'application/rtf' ;;
	rtx) printf 'text/richtext' ;;
	rw2) printf 'image/x-panasonic-raw' ;;
	rwl) printf 'image/x-panasonic-raw' ;;
	s) printf 'text/x-asm' ;;
	saf) printf 'application/vnd.yamaha.smaf-audio' ;;
	sbml) printf 'application/sbml+xml' ;;
	sc) printf 'application/vnd.ibm.secure-container' ;;
	scd) printf 'application/x-msschedule' ;;
	scm) printf 'application/vnd.lotus-screencam' ;;
	scq) printf 'application/scvp-cv-request' ;;
	scs) printf 'application/scvp-cv-response' ;;
	scurl) printf 'text/vnd.curl.scurl' ;;
	sda) printf 'application/vnd.stardivision.draw' ;;
	sdc) printf 'application/vnd.stardivision.calc' ;;
	sdd) printf 'application/vnd.stardivision.impress' ;;
	sdkd) printf 'application/vnd.solent.sdkm+xml' ;;
	sdkm) printf 'application/vnd.solent.sdkm+xml' ;;
	sdp) printf 'application/sdp' ;;
	sdw) printf 'application/vnd.stardivision.writer' ;;
	see) printf 'application/vnd.seemail' ;;
	seed) printf 'application/vnd.fdsn.seed' ;;
	sema) printf 'application/vnd.sema' ;;
	semd) printf 'application/vnd.semd' ;;
	semf) printf 'application/vnd.semf' ;;
	ser) printf 'application/java-serialized-object' ;;
	setpay) printf 'application/set-payment-initiation' ;;
	setreg) printf 'application/set-registration-initiation' ;;
	sfd-hdstx) printf 'application/vnd.hydrostatix.sof-data' ;;
	sfs) printf 'application/vnd.spotfire.sfs' ;;
	sgl) printf 'application/vnd.stardivision.writer-global' ;;
	sgm) printf 'text/sgml' ;;
	sgml) printf 'text/sgml' ;;
	sh) printf 'text/x-shellscript' ;;
	shar) printf 'application/x-shar' ;;
	shf) printf 'application/shf+xml' ;;
	si) printf 'text/vnd.wap.si' ;;
	sic) printf 'application/vnd.wap.sic' ;;
	sig) printf 'application/pgp-signature' ;;
	silo) printf 'model/mesh' ;;
	sis) printf 'application/vnd.symbian.install' ;;
	sisx) printf 'application/vnd.symbian.install' ;;
	sit) printf 'application/x-stuffit' ;;
	sitx) printf 'application/x-stuffitx' ;;
	skd) printf 'application/vnd.koan' ;;
	skm) printf 'application/vnd.koan' ;;
	skp) printf 'application/vnd.koan' ;;
	skt) printf 'application/vnd.koan' ;;
	sl) printf 'text/vnd.wap.sl' ;;
	slc) printf 'application/vnd.wap.slc' ;;
	sldm) printf 'application/vnd.ms-powerpoint.slide.macroenabled.12' ;;
	sldx) printf 'application/vnd.openxmlformats-officedocument.presentationml.slide' ;;
	slt) printf 'application/vnd.epson.salt' ;;
	smf) printf 'application/vnd.stardivision.math' ;;
	smi) printf 'application/smil+xml' ;;
	smil) printf 'application/smil+xml' ;;
	snd) printf 'audio/basic' ;;
	snf) printf 'application/x-font-snf' ;;
	so) printf 'application/octet-stream' ;;
	spc) printf 'application/x-pkcs7-certificates' ;;
	spf) printf 'application/vnd.yamaha.smaf-phrase' ;;
	spl) printf 'application/x-futuresplash' ;;
	spot) printf 'text/vnd.in3d.spot' ;;
	spp) printf 'application/scvp-vp-response' ;;
	spq) printf 'application/scvp-vp-request' ;;
	spx) printf 'audio/ogg' ;;
	sqlite) printf 'application/vnd.sqlite3' ;;
	sqlite-shm) printf 'application/vnd.sqlite3' ;;
	sqlite-wal) printf 'application/vnd.sqlite3' ;;
	sqlite3) printf 'application/vnd.sqlite3' ;;
	sr2) printf 'image/x-sony-sr2' ;;
	src) printf 'application/x-wais-source' ;;
	srf) printf 'image/x-sony-srf' ;;
	srx) printf 'application/sparql-results+xml' ;;
	sse) printf 'application/vnd.kodak-descriptor' ;;
	ssf) printf 'application/vnd.epson.ssf' ;;
	ssml) printf 'application/ssml+xml' ;;
	stc) printf 'application/vnd.sun.xml.calc.template' ;;
	std) printf 'application/vnd.sun.xml.draw.template' ;;
	stf) printf 'application/vnd.wt.stf' ;;
	sti) printf 'application/vnd.sun.xml.impress.template' ;;
	stk) printf 'application/hyperstudio' ;;
	stl) printf 'application/vnd.ms-pki.stl' ;;
	str) printf 'application/vnd.pg.format' ;;
	stw) printf 'application/vnd.sun.xml.writer.template' ;;
	sus) printf 'application/vnd.sus-calendar' ;;
	susp) printf 'application/vnd.sus-calendar' ;;
	sv4cpio) printf 'application/x-sv4cpio' ;;
	sv4crc) printf 'application/x-sv4crc' ;;
	svd) printf 'application/vnd.svd' ;;
	svg) printf 'image/svg+xml' ;;
	svgz) printf 'image/svg+xml' ;;
	swa) printf 'application/x-director' ;;
	swf) printf 'application/x-shockwave-flash' ;;
	swi) printf 'application/vnd.arastra.swi' ;;
	sxc) printf 'application/vnd.sun.xml.calc' ;;
	sxd) printf 'application/vnd.sun.xml.draw' ;;
	sxg) printf 'application/vnd.sun.xml.writer.global' ;;
	sxi) printf 'application/vnd.sun.xml.impress' ;;
	sxm) printf 'application/vnd.sun.xml.math' ;;
	sxw) printf 'application/vnd.sun.xml.writer' ;;
	t) printf 'text/troff' ;;
	tao) printf 'application/vnd.tao.intent-module-archive' ;;
	tar) printf 'application/x-tar' ;;
	tcap) printf 'application/vnd.3gpp2.tcap' ;;
	tcl) printf 'application/x-tcl' ;;
	teacher) printf 'application/vnd.smart.teacher' ;;
	test) printf 'test/mimetype' ;;
	tex) printf 'application/x-tex' ;;
	texi) printf 'application/x-texinfo' ;;
	texinfo) printf 'application/x-texinfo' ;;
	text) printf 'text/plain' ;;
	tfm) printf 'application/x-tex-tfm' ;;
	tgz) printf 'application/gzip' ;;
	tif) printf 'image/tiff' ;;
	tiff) printf 'image/tiff' ;;
	tmo) printf 'application/vnd.tmobile-livetv' ;;
	torrent) printf 'application/x-bittorrent' ;;
	tpl) printf 'application/vnd.groove-tool-template' ;;
	tpt) printf 'application/vnd.trid.tpt' ;;
	tr) printf 'text/troff' ;;
	tra) printf 'application/vnd.trueapp' ;;
	trm) printf 'application/x-msterminal' ;;
	ts) printf 'video/mp2t' ;;
	tsv) printf 'text/tab-separated-values' ;;
	ttc) printf 'application/x-font-ttf' ;;
	ttf) printf 'application/x-font-ttf' ;;
	twd) printf 'application/vnd.simtech-mindmapper' ;;
	twds) printf 'application/vnd.simtech-mindmapper' ;;
	txd) printf 'application/vnd.genomatix.tuxedo' ;;
	txf) printf 'application/vnd.mobius.txf' ;;
	txt) printf 'text/plain' ;;
	u32) printf 'application/x-authorware-bin' ;;
	udeb) printf 'application/vnd.debian.binary-package' ;;
	ufd) printf 'application/vnd.ufdl' ;;
	ufdl) printf 'application/vnd.ufdl' ;;
	umj) printf 'application/vnd.umajin' ;;
	unityweb) printf 'application/vnd.unity' ;;
	uoml) printf 'application/vnd.uoml+xml' ;;
	uri) printf 'text/uri-list' ;;
	uris) printf 'text/uri-list' ;;
	urls) printf 'text/uri-list' ;;
	ustar) printf 'application/x-ustar' ;;
	utz) printf 'application/vnd.uiq.theme' ;;
	uu) printf 'text/x-uuencode' ;;
	vcd) printf 'application/x-cdlink' ;;
	vcf) printf 'text/x-vcard' ;;
	vcg) printf 'application/vnd.groove-vcard' ;;
	vcs) printf 'text/x-vcalendar' ;;
	vcx) printf 'application/vnd.vcx' ;;
	vis) printf 'application/vnd.visionary' ;;
	viv) printf 'video/vnd.vivo' ;;
	vor) printf 'application/vnd.stardivision.writer' ;;
	vox) printf 'application/x-authorware-bin' ;;
	vrml) printf 'model/vrml' ;;
	vsd) printf 'application/vnd.visio' ;;
	vsdx) printf 'application/vnd.visio' ;;
	vsf) printf 'application/vnd.vsf' ;;
	vss) printf 'application/vnd.visio' ;;
	vssm) printf 'application/vnd.visio' ;;
	vssx) printf 'application/vnd.visio' ;;
	vst) printf 'application/vnd.visio' ;;
	vstm) printf 'application/vnd.visio' ;;
	vstx) printf 'application/vnd.visio' ;;
	vsw) printf 'application/vnd.visio' ;;
	vtu) printf 'model/vnd.vtu' ;;
	vxml) printf 'application/voicexml+xml' ;;
	w3d) printf 'application/x-director' ;;
	wad) printf 'application/x-doom' ;;
	wasm) printf 'application/wasm' ;;
	wav) printf 'audio/vnd.wav' ;;
	wax) printf 'audio/x-ms-wax' ;;
	wbmp) printf 'image/vnd.wap.wbmp' ;;
	wbs) printf 'application/vnd.criticaltools.wbs+xml' ;;
	wbxml) printf 'application/vnd.wap.wbxml' ;;
	wcm) printf 'application/vnd.ms-works' ;;
	wdb) printf 'application/vnd.ms-works' ;;
	weba) printf 'audio/webm' ;;
	webm) printf 'video/webm' ;;
	webp) printf 'image/webp' ;;
	whl) printf 'text/x-python' ;;
	wiz) printf 'application/msword' ;;
	wks) printf 'application/vnd.ms-works' ;;
	wm) printf 'video/x-ms-wm' ;;
	wma) printf 'audio/x-ms-wma' ;;
	wmd) printf 'application/x-ms-wmd' ;;
	wmf) printf 'application/x-msmetafile' ;;
	wml) printf 'text/vnd.wap.wml' ;;
	wmlc) printf 'application/vnd.wap.wmlc' ;;
	wmls) printf 'text/vnd.wap.wmlscript' ;;
	wmlsc) printf 'application/vnd.wap.wmlscriptc' ;;
	wmv) printf 'video/x-ms-wmv' ;;
	wmx) printf 'video/x-ms-wmx' ;;
	wmz) printf 'application/x-ms-wmz' ;;
	woff) printf 'font/woff' ;;
	woff2) printf 'font/woff2' ;;
	wpd) printf 'application/vnd.wordperfect' ;;
	wpl) printf 'application/vnd.ms-wpl' ;;
	wps) printf 'application/vnd.ms-works' ;;
	wqd) printf 'application/vnd.wqd' ;;
	wri) printf 'application/x-mswrite' ;;
	wrl) printf 'model/vrml' ;;
	wsdl) printf 'application/wsdl+xml' ;;
	wspolicy) printf 'application/wspolicy+xml' ;;
	wtb) printf 'application/vnd.webturbo' ;;
	wvx) printf 'video/x-ms-wvx' ;;
	x32) printf 'application/x-authorware-bin' ;;
	x3d) printf 'application/vnd.hzn-3d-crossword' ;;
	x3f) printf 'image/x-sigma-x3f' ;;
	xap) printf 'application/x-silverlight-app' ;;
	xar) printf 'application/vnd.xara' ;;
	xbap) printf 'application/x-ms-xbap' ;;
	xbd) printf 'application/vnd.fujixerox.docuworks.binder' ;;
	xbm) printf 'image/x-xbitmap' ;;
	xdm) printf 'application/vnd.syncml.dm+xml' ;;
	xdp) printf 'application/vnd.adobe.xdp+xml' ;;
	xdw) printf 'application/vnd.fujixerox.docuworks' ;;
	xenc) printf 'application/xenc+xml' ;;
	xer) printf 'application/patch-ops-error+xml' ;;
	xfdf) printf 'application/vnd.adobe.xfdf' ;;
	xfdl) printf 'application/vnd.xfdl' ;;
	xht) printf 'application/xhtml+xml' ;;
	xhtml) printf 'application/xhtml+xml' ;;
	xhvml) printf 'application/xv+xml' ;;
	xif) printf 'image/vnd.xiff' ;;
	xla) printf 'application/vnd.ms-excel' ;;
	xlam) printf 'application/vnd.ms-excel.addin.macroenabled.12' ;;
	xlb) printf 'application/vnd.ms-excel' ;;
	xlc) printf 'application/vnd.ms-excel' ;;
	xlm) printf 'application/vnd.ms-excel' ;;
	xls) printf 'application/vnd.ms-excel' ;;
	xlsb) printf 'application/vnd.ms-excel.sheet.binary.macroenabled.12' ;;
	xlsm) printf 'application/vnd.ms-excel.sheet.macroenabled.12' ;;
	xlsx) printf 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ;;
	xlt) printf 'application/vnd.ms-excel' ;;
	xltm) printf 'application/vnd.ms-excel.template.macroenabled.12' ;;
	xltx) printf 'application/vnd.openxmlformats-officedocument.spreadsheetml.template' ;;
	xlw) printf 'application/vnd.ms-excel' ;;
	xml) printf 'application/rss+xml' ;;
	xo) printf 'application/vnd.olpc-sugar' ;;
	xop) printf 'application/xop+xml' ;;
	xpdl) printf 'application/xml' ;;
	xpi) printf 'application/x-xpinstall' ;;
	xpm) printf 'image/x-xpixmap' ;;
	xpr) printf 'application/vnd.is-xpr' ;;
	xps) printf 'application/vnd.ms-xpsdocument' ;;
	xpw) printf 'application/vnd.intercon.formnet' ;;
	xpx) printf 'application/vnd.intercon.formnet' ;;
	xsl) printf 'application/xml' ;;
	xslt) printf 'application/xslt+xml' ;;
	xsm) printf 'application/vnd.syncml+xml' ;;
	xspf) printf 'application/xspf+xml' ;;
	xul) printf 'application/vnd.mozilla.xul+xml' ;;
	xvm) printf 'application/xv+xml' ;;
	xvml) printf 'application/xv+xml' ;;
	xwd) printf 'image/x-xwindowdump' ;;
	xyz) printf 'chemical/x-xyz' ;;
	xz) printf 'application/x-xz' ;;
	yaml) printf 'application/yaml' ;;
	yml) printf 'application/yaml' ;;
	zabw) printf 'application/x-abiword' ;;
	zaz) printf 'application/vnd.zzazz.deck+xml' ;;
	zip) printf 'application/x-zip-compressed' ;;
	zir) printf 'application/vnd.zul' ;;
	zirz) printf 'application/vnd.zul' ;;
	zmm) printf 'application/vnd.handheld-entertainment+xml' ;;
	*)
		return 1
		;;
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

# ===========================================================================
# HASH MODULE
# ===========================================================================

# A complete, standalone bag of checksum tools: the md5/SHA family, crc32,
# blake2, a generic dispatcher, string hashing, verification, comparison,
# containment, directory diff/minus and duplicate finding. Every function
# prints its result on stdout and returns non-zero on failure. No globals
# required.

# ---------------------------------------------------------------------------
# Direct per-algorithm getters (binary-safe, first field of the sum line)
# ---------------------------------------------------------------------------

Get_MD5Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v md5sum >/dev/null || return 127

	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_SHA1Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha1sum >/dev/null || return 127

	Sum=$(sha1sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_SHA224Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha224sum >/dev/null || return 127

	Sum=$(sha224sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_SHA256Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha256sum >/dev/null || return 127

	Sum=$(sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_SHA384Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha384sum >/dev/null || return 127

	Sum=$(sha384sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_SHA512Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v sha512sum >/dev/null || return 127

	Sum=$(sha512sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_B2Sum() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v b2sum >/dev/null || return 127

	Sum=$(b2sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

Get_CRC32() {
	local File=$1
	local Sum

	[ -f "$File" ] || return 1
	command -v cksum >/dev/null || return 127

	Sum=$(cksum -- "$File" 2>/dev/null | cut -d' ' -f1)
	[ -n "$Sum" ] || return 1
	printf '%s' "$Sum"
}

# ---------------------------------------------------------------------------
# Generic dispatcher: Get_Hash <algo> <file>
# algo: md5 | sha1 | sha224 | sha256 | sha384 | sha512 | b2 | crc32
# ---------------------------------------------------------------------------

Get_Hash() {
	local Algo=${1,,}
	local File=$2

	case "$Algo" in
	md5) Get_MD5Sum "$File" ;;
	sha1) Get_SHA1Sum "$File" ;;
	sha224) Get_SHA224Sum "$File" ;;
	sha256) Get_SHA256Sum "$File" ;;
	sha384) Get_SHA384Sum "$File" ;;
	sha512) Get_SHA512Sum "$File" ;;
	b2 | blake2) Get_B2Sum "$File" ;;
	crc32 | cksum) Get_CRC32 "$File" ;;
	*)
		printf 'ERROR' >&2
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# String hashing: Get_Hash_Of_String <algo> <string>
# ---------------------------------------------------------------------------

Get_Hash_Of_String() {
	local Algo=${1,,}
	local String=$2
	local Sum

	[ -n "$String" ] || return 1

	case "$Algo" in
	md5)
		command -v md5sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | md5sum)
		;;
	sha1)
		command -v sha1sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha1sum)
		;;
	sha224)
		command -v sha224sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha224sum)
		;;
	sha256)
		command -v sha256sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha256sum)
		;;
	sha384)
		command -v sha384sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha384sum)
		;;
	sha512)
		command -v sha512sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha512sum)
		;;
	b2 | blake2)
		command -v b2sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | b2sum)
		;;
	crc32 | cksum)
		command -v cksum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | cksum)
		;;
	*) return 1 ;;
	esac

	printf '%s' "${Sum%% *}"
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

Verify_Hash() {
	local File=$1
	local Expected=$2
	local Actual

	Actual=$(Get_Hash sha256 "$File") || return 1
	[[ "$Actual" == "${Expected,,}" ]]
}

Files_Are_Identical() {
	local A=$1
	local B=$2

	[ -f "$A" ] && [ -f "$B" ] || return 1
	cmp -s -- "$A" "$B"
}

Same_Hash() {
	local A=$1
	local B=$2
	local Algo=${3:-sha256}
	local HashA HashB

	HashA=$(Get_Hash "$Algo" "$A") || return 1
	HashB=$(Get_Hash "$Algo" "$B") || return 1
	[[ "$HashA" == "$HashB" ]]
}

Files_Differ() {
	local A=$1
	local B=$2

	[ -f "$A" ] && [ -f "$B" ] || return 1
	command -v cmp >/dev/null || return 127

	! cmp -s -- "$A" "$B"
}

# ---------------------------------------------------------------------------
# Containment: is the content of A inside B?
# File_Contains <needle-file> <haystack-file>
# Swap the arguments to ask the reverse question.
# ---------------------------------------------------------------------------

File_Contains() {
	local Needle=$1
	local Haystack=$2
	local Encoding Content

	[ -f "$Needle" ] && [ -f "$Haystack" ] || return 1
	[ -s "$Needle" ] || return 1
	command -v grep >/dev/null || return 127

	# Text fast path: grep -F matches the whole needle, newlines included.
	Encoding=$(file -b --mime-encoding -- "$Needle" 2>/dev/null)
	if [ "$Encoding" != "binary" ] && command -v file >/dev/null; then
		Content=$(cat -- "$Needle") || return 1
		grep -qaF -- "$Content" "$Haystack"
		return $?
	fi

	# Binary-safe path (needle contains NUL bytes): compare hex streams.
	command -v od >/dev/null || return 127
	local NeedleHex HaystackHex
	NeedleHex=$(od -An -v -tx1 -- "$Needle" 2>/dev/null | tr -d ' \n') || return 1
	HaystackHex=$(od -An -v -tx1 -- "$Haystack" 2>/dev/null | tr -d ' \n') || return 1
	[[ "$HaystackHex" == *"$NeedleHex"* ]]
}

# ---------------------------------------------------------------------------
# A is in B: find files inside a directory that are identical to a file.
# Find_Copy_In <file> <dir> [algo]
# ---------------------------------------------------------------------------

Find_Copy_In() {
	local File=$1
	local Dir=$2
	local Algo=${3:-sha256}
	local TargetHash Sum Candidate

	[ -f "$File" ] && [ -d "$Dir" ] || return 1

	TargetHash=$(Get_Hash "$Algo" "$File") || return $?

	find "$Dir" -type f -print0 2>/dev/null |
		while IFS= read -r -d '' Candidate; do
			# Skip the file itself (same inode via hardlink or identical path).
			[[ "$Candidate" -ef "$File" ]] && continue
			Sum=$(Get_Hash "$Algo" "$Candidate") || continue
			[[ "$Sum" == "$TargetHash" ]] && printf '%s\n' "$Candidate"
		done
}

# ---------------------------------------------------------------------------
# Directory comparison: Dir_Diff <dirA> <dirB> [algo]
# Prints one line per relative file path:
#   SAME\t<path>       identical content in both trees
#   DIFFERENT\t<path>  present in both, different content
#   ONLY_IN_A\t<path>  missing from B ("A minus B")
#   ONLY_IN_B\t<path>  missing from A
# Only regular files are compared; empty directories are ignored.
# ---------------------------------------------------------------------------

Dir_Diff() {
	local DirA=${1%/}
	local DirB=${2%/}
	local Algo=${3:-sha256}
	local PathA PathB Rel HashA HashB

	[ -d "$DirA" ] && [ -d "$DirB" ] || return 1

	{
		find "$DirA" -type f -print0 2>/dev/null |
			while IFS= read -r -d '' PathA; do
				Rel=${PathA#"$DirA"/}
				PathB="$DirB/$Rel"
				if [ ! -e "$PathB" ]; then
					printf 'ONLY_IN_A\t%s\n' "$Rel"
				else
					HashA=$(Get_Hash "$Algo" "$PathA") || continue
					HashB=$(Get_Hash "$Algo" "$PathB") || continue
					if [[ "$HashA" == "$HashB" ]]; then
						printf 'SAME\t%s\n' "$Rel"
					else
						printf 'DIFFERENT\t%s\n' "$Rel"
					fi
				fi
			done

		find "$DirB" -type f -print0 2>/dev/null |
			while IFS= read -r -d '' PathB; do
				Rel=${PathB#"$DirB"/}
				[ -e "$DirA/$Rel" ] || printf 'ONLY_IN_B\t%s\n' "$Rel"
			done
	} | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# A minus B (by path): relative paths of files that exist in A but not in B.
# Dir_Minus <dirA> <dirB>
# ---------------------------------------------------------------------------

Dir_Minus() {
	local DirA=${1%/}
	local DirB=${2%/}
	local PathA Rel

	[ -d "$DirA" ] && [ -d "$DirB" ] || return 1

	find "$DirA" -type f -print0 2>/dev/null |
		while IFS= read -r -d '' PathA; do
			Rel=${PathA#"$DirA"/}
			[ -e "$DirB/$Rel" ] || printf '%s\n' "$Rel"
		done
}

# ---------------------------------------------------------------------------
# A minus B (by content): paths of files in A whose content does not exist
# anywhere in B, regardless of name or location.
# Dir_Minus_Content <dirA> <dirB> [algo]
# ---------------------------------------------------------------------------

Dir_Minus_Content() {
	local DirA=${1%/}
	local DirB=${2%/}
	local Algo=${3:-sha256}
	local BHashes PathA PathB Hash Sum

	[ -d "$DirA" ] && [ -d "$DirB" ] || return 1

	# Hash every file in B once, keep the unique set.
	BHashes=$(
		find "$DirB" -type f -print0 2>/dev/null |
			while IFS= read -r -d '' PathB; do
				Hash=$(Get_Hash "$Algo" "$PathB" 2>/dev/null) && printf '%s\n' "$Hash"
			done | LC_ALL=C sort -u
	)

	find "$DirA" -type f -print0 2>/dev/null |
		while IFS= read -r -d '' PathA; do
			Sum=$(Get_Hash "$Algo" "$PathA") || continue
			# An empty B matches nothing, so every file of A is reported.
			if [ -n "$BHashes" ] && printf '%s\n' "$BHashes" | grep -qx "$Sum"; then
				continue
			fi
			printf '%s\n' "$PathA"
		done
}

# ---------------------------------------------------------------------------
# Predicate: are two directory trees content-identical?
# Dir_Same <dirA> <dirB> [algo]
# ---------------------------------------------------------------------------

Dir_Same() {
	local DirA=$1
	local DirB=$2
	local Algo=${3:-sha256}
	local Out

	Out=$(Dir_Diff "$DirA" "$DirB" "$Algo") || return $?
	# Identical trees produce only SAME lines (or no lines at all).
	! printf '%s\n' "$Out" | grep -qv $'^SAME\t'
}

# ---------------------------------------------------------------------------
# Fast sample hash for very large files: size + first/last 1 MB hashed.
# NOT cryptographic - for quick duplicate screening only.
# ---------------------------------------------------------------------------

Get_Quick_Hash() {
	local File=$1
	local Size Head Tail

	[ -f "$File" ] || return 1
	command -v sha256sum >/dev/null || return 127

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	Head=$(head -c 1048576 -- "$File" 2>/dev/null | sha256sum | cut -d' ' -f1)
	Tail=$(tail -c 1048576 -- "$File" 2>/dev/null | sha256sum | cut -d' ' -f1)

	[ -n "$Head" ] && [ -n "$Tail" ] || return 1
	printf '%s-%s-%s' "$Size" "${Head:0:16}" "${Tail:0:16}"
}

# ---------------------------------------------------------------------------
# Duplicate finder: Find_Duplicates <dir> [algo]
# Prints groups of identical files, one group per block, separated by " --- ".
# ---------------------------------------------------------------------------

Find_Duplicates() {
	local Dir=$1
	local Algo=${2:-sha256}
	local Sum File

	[ -d "$Dir" ] || return 1

	find "$Dir" -type f ! -empty -print0 2>/dev/null |
		while IFS= read -r -d '' File; do
			Sum=$(Get_Hash "$Algo" "$File") || continue
			printf '%s\t%s\n' "$Sum" "$File"
		done | sort | awk -F'\t' '
		$1 == prev { if (prevfile != "") print prevfile; print $2; prevfile="" ; seen=1 ; prev=$1 ; next }
		{ if (seen) print " --- " ; seen=0 ; prev=$1 ; prevfile=$2 }
	'
}

# ===========================================================================
# IMAGEMAGICK MODULE
# ===========================================================================

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

# ===========================================================================
# FFMPEG MODULE
# ===========================================================================

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

# ===========================================================================
# EXIF MODULE
# ===========================================================================

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

# ===========================================================================
# COMPRESSION MODULE
# ===========================================================================

# Archive toolkit: tar / gz / bz2 / xz / zst / zip / 7z / rar - type detection
# by magic bytes, integrity testing, listing, extraction, main-name lookup,
# creation and single-file compression. Missing tools are proposed for install
# through the deps init-system.

# A complete, standalone bag of archive tools: type detection by magic bytes,
# integrity testing, listing, extraction, creation and single-file compression
# for the tar family (plain, gz, bz2, xz, zst), zip, 7z and rar. Every function
# prints its result on stdout and returns non-zero on failure (127 = tool
# missing, 1 = file/argument problem). Missing tools are proposed for install
# through the deps init-system when it is loaded.

# ---------------------------------------------------------------------------
# Internal: deps hook - propose an install for a missing tool (once)
# ---------------------------------------------------------------------------

_Comp_Have() {
	local Tool=$1

	command -v "$Tool" >/dev/null 2>&1 && return 0
	declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure "$Tool"
	command -v "$Tool" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Internal: keep leading-dash filenames away from tool option parsing
# _Comp_Norm <file-or-dir>
# ---------------------------------------------------------------------------

_Comp_Norm() {
	local Path=$1

	case "$Path" in
	-) printf './-' ;;
	-*) printf './%s' "$Path" ;;
	*) printf '%s' "$Path" ;;
	esac
}

# ---------------------------------------------------------------------------
# Internal: does the filename say .tar.<something> (tar auto-decompresses)?
# _Comp_Is_Tar_Suffix <file>
# ---------------------------------------------------------------------------

_Comp_Is_Tar_Suffix() {
	local Base=${1##*/}
	Base=${Base,,}

	case "$Base" in
	*.tar.gz | *.tgz | *.tar.bz2 | *.tbz2 | *.tbz | *.tar.xz | *.txz | *.tar.zst | *.tzst) return 0 ;;
	*) return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# Internal: read the first bytes of a file as a hex string
# _Comp_Magic <file> <count>
# ---------------------------------------------------------------------------

_Comp_Magic() {
	local File=$1 Count=$2

	[ -f "$File" ] || return 1
	head -c "$Count" -- "$File" 2>/dev/null | od -An -tx1 | tr -d ' \n'
}

# ---------------------------------------------------------------------------
# Archive type by magic bytes (extension only as a last resort).
# Get_Archive_Type <file>   -> tar | gzip | bzip2 | xz | zstd | zip | 7z | rar
# Returns 1 when the file is not a recognized archive.
# ---------------------------------------------------------------------------

Get_Archive_Type() {
	local File=$1
	local Hex TarMagic

	[ -f "$File" ] || return 1

	Hex=$(_Comp_Magic "$File" 8) || return 1

	case "$Hex" in
	1f8b*)
		printf 'gzip'
		return 0
		;;
	425a68*)
		printf 'bzip2'
		return 0
		;;
	fd377a585a00*)
		printf 'xz'
		return 0
		;;
	28b52ffd*)
		printf 'zstd'
		return 0
		;;
	504b03* | 504b05* | 504b07*)
		printf 'zip'
		return 0
		;;
	377abcaf271c*)
		printf '7z'
		return 0
		;;
	526172211a07*)
		printf 'rar'
		return 0
		;;
	esac

	# tar: 'ustar' at byte offset 257 (POSIX and GNU)
	TarMagic=$(tail -c +258 -- "$File" 2>/dev/null | head -c 5 | od -An -tx1 | tr -d ' \n')
	if [ "$TarMagic" = '7573746172' ]; then
		printf 'tar'
		return 0
	fi

	return 1
}

# ---------------------------------------------------------------------------
# Boolean wrapper: is the file a recognized archive?
# Archive_Is <file>   (rc 0 = yes, 1 = no)
# ---------------------------------------------------------------------------

Archive_Is() {
	Get_Archive_Type "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Integrity test of an archive.
# Archive_Test <file>   (rc 0 = intact, 1 = corrupt/failed, 127 = tool missing)
# ---------------------------------------------------------------------------

Archive_Test() {
	local File=$1
	local Type

	File=$(_Comp_Norm "$File")
	Type=$(Get_Archive_Type "$File") || return 1

	case "$Type" in
	tar)
		_Comp_Have tar || return 127
		tar -tf "$File" >/dev/null 2>&1
		;;
	gzip | bzip2 | xz | zstd)
		if _Comp_Is_Tar_Suffix "$File"; then
			_Comp_Have tar || return 127
			tar -tf "$File" >/dev/null 2>&1
			return $?
		fi
		case "$Type" in
		gzip)
			_Comp_Have gzip || return 127
			gzip -t -- "$File" 2>/dev/null
			;;
		bzip2)
			_Comp_Have bzip2 || return 127
			bzip2 -t -- "$File" 2>/dev/null
			;;
		xz)
			_Comp_Have xz || return 127
			xz -t -- "$File" 2>/dev/null
			;;
		zstd)
			_Comp_Have zstd || return 127
			zstd -t -- "$File" 2>/dev/null
			;;
		esac
		;;
	zip)
		_Comp_Have unzip || return 127
		unzip -t -qq -- "$File" >/dev/null 2>&1
		;;
	7z)
		_Comp_Have 7z || return 127
		7z t -y -- "$File" >/dev/null 2>&1
		;;
	rar)
		_Comp_Have unrar || return 127
		unrar t -y -- "$File" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# List the entries of an archive, one per line.
# Archive_List <file>   (stdout: entry paths; rc 1/127 on failure)
# ---------------------------------------------------------------------------

Archive_List() {
	local File=$1
	local Type

	File=$(_Comp_Norm "$File")
	Type=$(Get_Archive_Type "$File") || return 1

	case "$Type" in
	tar)
		_Comp_Have tar || return 127
		tar -tf "$File" 2>/dev/null
		;;
	gzip | bzip2 | xz | zstd)
		if _Comp_Is_Tar_Suffix "$File"; then
			_Comp_Have tar || return 127
			tar -tf "$File" 2>/dev/null
			return $?
		fi
		case "$Type" in
		gzip)
			_Comp_Have gzip || return 127
			gzip -l -- "$File" 2>/dev/null | tail -n +2 | awk '{print $4}'
			;;
		bzip2)
			_Comp_Have bzip2 || return 127
			bzip2 -l -- "$File" 2>/dev/null | tail -n +2 | awk '{print $4}'
			;;
		xz)
			_Comp_Have xz || return 127
			xz -l -- "$File" 2>/dev/null | awk '{print $1}' | tail -n +2
			;;
		zstd)
			_Comp_Have zstd || return 127
			zstd -l -- "$File" 2>/dev/null | awk 'NR>2 {print $1}'
			;;
		esac
		;;
	zip)
		_Comp_Have unzip || return 127
		unzip -Z1 -- "$File" 2>/dev/null
		;;
	7z)
		_Comp_Have 7z || return 127
		7z l -y -- "$File" 2>/dev/null | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {print $NF}'
		;;
	rar)
		_Comp_Have unrar || return 127
		unrar lb -- "$File" 2>/dev/null
		;;
	*)
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# Extract an archive into a directory (created when missing).
# Archive_Extract <file> <destdir>   (rc 0 = ok, 1 = failed, 127 = tool missing)
# ---------------------------------------------------------------------------

Archive_Extract() {
	local File=$1 Dest=$2
	local Type Base Out

	File=$(_Comp_Norm "$File")
	Dest=$(_Comp_Norm "$Dest")
	Type=$(Get_Archive_Type "$File") || return 1
	mkdir -p -- "$Dest" || return 1

	case "$Type" in
	tar)
		_Comp_Have tar || return 127
		tar -xaf "$File" -C "$Dest" 2>/dev/null
		;;
	gzip | bzip2 | xz | zstd)
		if _Comp_Is_Tar_Suffix "$File"; then
			_Comp_Have tar || return 127
			tar -xaf "$File" -C "$Dest" 2>/dev/null
			return $?
		fi
		Base=${File##*/}
		case "$Base" in
		*.gz) Out=${Base%.gz} ;;
		*.bz2) Out=${Base%.bz2} ;;
		*.xz) Out=${Base%.xz} ;;
		*.zst | *.zstd) Out=${Base%.zst} ;;
		*) Out="$Base.out" ;;
		esac
		case "$Type" in
		gzip)
			_Comp_Have gunzip || return 127
			gunzip -c -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		bzip2)
			_Comp_Have bunzip2 || return 127
			bunzip2 -c -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		xz)
			_Comp_Have xz || return 127
			xz -dc -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		zstd)
			_Comp_Have zstd || return 127
			zstd -dc -- "$File" >"$Dest/$Out" 2>/dev/null
			;;
		esac
		;;
	zip)
		_Comp_Have unzip || return 127
		unzip -o -q -- "$File" -d "$Dest" 2>/dev/null
		;;
	7z)
		_Comp_Have 7z || return 127
		7z x -y -o"$Dest" -- "$File" >/dev/null 2>&1
		;;
	rar)
		_Comp_Have unrar || return 127
		unrar x -y -- "$File" "$Dest/" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# Name of the main directory inside an archive, or of its single contained
# file (extension stripped) - the natural name for --rename=compressed.
# Archive_Main_Name <file>   (stdout: name; rc 1 = ambiguous / empty / error)
# ---------------------------------------------------------------------------

Archive_Main_Name() {
	local File=$1
	local Entries Top Name='' Extra=0

	Entries=$(Archive_List "$File") || return 1

	# Unique top-level entries (first path component)
	while IFS= read -r Entry; do
		[ -n "$Entry" ] || continue
		Entry=${Entry#./}
		Top=${Entry%%/*}
		[ -n "$Top" ] || Top=$Entry
		if [ -z "$Name" ]; then
			Name=$Top
		elif [ "$Name" != "$Top" ]; then
			Extra=$((Extra + 1))
		fi
	done <<<"$Entries"

	[ -n "$Name" ] || return 1
	[ "$Extra" -eq 0 ] || return 1

	# A directory entry lists children as <Name>/... (single-file entries do not)
	if [[ "$Entries" == *"$Name"/* ]]; then
		printf '%s' "$Name"
		return 0
	fi

	# Single file: strip one trailing extension
	printf '%s' "${Name%.*}"
}

# ---------------------------------------------------------------------------
# Single-file compression: replaces <file> with <file>.<ext> (like gzip).
# Compress_File <file> <gzip|bzip2|xz|zstd>   (rc 0/1/127)
# ---------------------------------------------------------------------------

Compress_File() {
	local File=$1 Format=$2

	[ -f "$File" ] || return 1

	case "$Format" in
	gzip)
		_Comp_Have gzip || return 127
		gzip -f -- "$File"
		;;
	bzip2)
		_Comp_Have bzip2 || return 127
		bzip2 -f -- "$File"
		;;
	xz)
		_Comp_Have xz || return 127
		xz -f -- "$File"
		;;
	zstd)
		_Comp_Have zstd || return 127
		zstd -f -- "$File"
		;;
	*)
		return 1
		;;
	esac
}

# Convenience wrappers
Compress_Gzip() { Compress_File "$1" gzip; }
Compress_Bzip2() { Compress_File "$1" bzip2; }
Compress_Xz() { Compress_File "$1" xz; }
Compress_Zstd() { Compress_File "$1" zstd; }

# ---------------------------------------------------------------------------
# Create an archive from files/directories; the format follows the extension
# of <archive> (.tar, .tar.gz/.tgz, .tar.bz2, .tar.xz, .tar.zst, .zip, .7z).
# Archive_Create <archive> <file>...
# ---------------------------------------------------------------------------

Archive_Create() {
	local Archive
	Archive=$(_Comp_Norm "$1")
	shift
	local Low=${Archive,,}

	[ $# -ge 1 ] || return 1

	case "$Low" in
	*.tar.gz | *.tgz)
		_Comp_Have tar || return 127
		tar -czf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar.bz2)
		_Comp_Have tar || return 127
		tar -cjf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar.xz)
		_Comp_Have tar || return 127
		tar -cJf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar.zst)
		_Comp_Have tar || return 127
		tar --zstd -cf "$Archive" -- "$@" 2>/dev/null
		;;
	*.tar)
		_Comp_Have tar || return 127
		tar -cf "$Archive" -- "$@" 2>/dev/null
		;;
	*.zip)
		_Comp_Have zip || return 127
		zip -r -q "$Archive" -- "$@" 2>/dev/null
		;;
	*.7z)
		_Comp_Have 7z || return 127
		7z a -y -- "$Archive" "$@" >/dev/null 2>&1
		;;
	*)
		return 1
		;;
	esac
}

# ===========================================================================
# DOCS MODULE
# ===========================================================================

# Document helpers: internal document title extraction from PDFs and office documents via pdftotext/exiftool.

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

	# Fall back to the existing filename when no title could be extracted.
	[[ -z "$Title" ]] && Title=$(Get_File_Name "$File")

	printf '%s' "${Title:-ERROR}"
}

# ===========================================================================
# DRIVER - defaults, parsing, the dynamic-value engine and the thread pool
# ===========================================================================

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

Modus='Print'                                              # Print / Copy / Move / Remove / Trash / Shred
Replace='No'                                               # overwrite existing targets?
Rename=''                                                  # '' = folder_name, or any dynamic keyword
Append=''                                                  # '' = original extension, none, keyword or literal
Dirs_Spec=''                                               # --dirs= segment list (default: mime)
SubDirs_Spec=''                                            # --subdirs= segment list (default: per kind)
Target_Dir='.'                                             # --target= base directory of the sorted tree
Type_Filter=''                                             # --type= MIME substring filter
Pause=0                                                    # --pause= seconds waited after each file
LogFile=''                                                 # --log= append a line per action
UndoFile=''                                                # --undo[=FILE] write an undo script
Title_Mode=0                                               # --title metadata-title naming
Quiet=0                                                    # 1 = per-file details suppressed
Use_EXIF=0                                                 # 1 = add <Camera>/<date> levels for images
Strip=0                                                    # 1 = strip EXIF/GPS metadata from targets
Hidden=0                                                   # 1 = include hidden files/directories
Links=0                                                    # 1 = include symbolic links
Recursive=0                                                # 1 = walk directories to full depth
Max_Jobs=$(command -v nproc >/dev/null && nproc || echo 4) # thread pool size
Decompress=0                                               # 1 = extract archives first and sort the contents
Decompress_Depth=0                                         # current --decompress nesting depth

Files=()   # raw arguments that are files/directories
Targets=() # every single file to treat, collected up front

# ---------------------------------------------------------------------------
# Usage - the short reminder printed when no arguments are given
# ---------------------------------------------------------------------------

Usage() {
	Print_Header 'Sort 17.0 - self-contained threaded organizer'
	Print_Message 'Usage: Sort.sh [options] <file|directory> ...'
	printf '\n'
	Print_Message 'Common starts:'
	printf '\n'
	printf '\t%s\n' 'Sort.sh --copy --replace ~/Pictures/2Sort'
	printf '\t%s\n' 'Sort.sh --move --rename=sha256sum --extension=none .'
	printf '\t%s\n' 'Sort.sh --recursive --dirs=year+month --type=image ~/Pics'
	printf '\t%s\n' 'Sort.sh --colored --jobs=8 --exif --target=~/Sorted ~/Pics'
	printf '\t%s\n' 'Sort.sh --decompress --dirs=mime ~/Archives'
	printf '\n'
	Print_Message 'Use --help for the full option list and dynamic values.'
}

# ---------------------------------------------------------------------------
# Help - the complete option reference
# ---------------------------------------------------------------------------

Help() {
	Print_Header 'Sort 17.0 - self-contained threaded organizer'
	Print_Message 'Sorts files into a dynamic directory tree built from MIME, dates,'
	Print_Message 'sizes, media dimensions, checksums and metadata titles.'
	printf '\n'
	Print_Header 'Modes' '='
	printf '\t%s\n' '(default)          Preview only - print source <=> target'
	printf '\t%s\n' '--copy             Copy every file to its sorted location'
	printf '\t%s\n' '--move             Move every file to its sorted location'
	printf '\t%s\n' '--remove           Remove the file at the calculated TARGET path'
	printf '\t%s\n' '--delete           Alias for --remove'
	printf '\t%s\n' '--trash            Send the calculated target to the desktop trash'
	printf '\t%s\n' '--shred            Run shred -u -n 1 on the calculated target'
	printf '\t%s\n' '--mode=VALUE       Long form of any mode above (copy/move/...)'
	printf '\n'
	Print_Message 'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET'
	Print_Message 'path, not on the source. Source = target is refused. Review the'
	Print_Message 'preview output before using a destructive mode.'
	printf '\n'
	Print_Header 'Filtering and processing' '='
	printf '\t%s\n' '--type=VALUE       Only files whose MIME type contains VALUE'
	printf '\t%s\n' '                   (image, video, audio, pdf, application, ...)'
	printf '\t%s\n' '--recursive        Walk supplied directories to full depth'
	printf '\t%s\n' '--hidden           Include hidden files and directories'
	printf '\t%s\n' '--links            Include symbolic links'
	printf '\t%s\n' '--pause=SECONDS    Wait after each file'
	printf '\t%s\n' '--jobs=N           Thread pool size (default: nproc, min 1)'
	printf '\n'
	Print_Header 'Destination and naming' '='
	printf '\t%s\n' '--target=DIR       Base directory of the sorted tree (default: .)'
	printf '\t%s\n' '--dirs=LIST        Primary directory components (default: mime)'
	printf '\t%s\n' '--subdirs=LIST     Directory components beneath the primary'
	printf '\t%s\n' '--rename=VALUE     Generate the filename (without extension)'
	printf '\t%s\n' '--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)'
	printf '\t%s\n' '--title            Filename from embedded metadata (PDF /Title,'
	printf '\t%s\n' '                   image EXIF date, audio/video tags)'
	printf '\t%s\n' '--replace          Overwrite existing targets, else unique ~(N) name'
	printf '\n'
	Print_Header 'EXIF / metadata' '='
	printf '\t%s\n' '--exif             Add <Camera>/<YYYY-MM-DD> levels for images'
	printf '\t%s\n' '--strip            Strip EXIF/GPS metadata from targets after copy/move'
	printf '\n'
	Print_Header 'Archives' '='
	printf '\t%s\n' '--decompress       Extract archives to a temp dir and sort the contents'
	printf '\t%s\n' '                   (the archive itself is deleted after success;'
	printf '\t%s\n' '                   --trash / --shred apply that fate to it instead)'
	printf '\t%s\n' '--rename=compressed  Name = main dir / single file inside the archive'
	printf '\n'
	Print_Header 'Output and safety' '='
	printf '\t%s\n' '--colored          Force colored output (auto-detected on a tty)'
	printf '\t%s\n' '--colors           Alias for --colored'
	printf '\t%s\n' '--quiet            Per-file details off; summary only'
	printf '\t%s\n' '--verbose          Per-file details on (default)'
	printf '\t%s\n' '--stats            Print the summary (default)'
	printf '\t%s\n' '--log=FILE         Append one line per action to FILE'
	printf '\t%s\n' '--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)'
	printf '\t%s\n' '--usage            Short reminder'
	printf '\t%s\n' '--help             This help'
	printf '\t%s\n' '--version          Print the version'
	printf '\n'
	Print_Header 'Dynamic values' '='
	Print_Message 'Case-insensitive keywords for --dirs, --subdirs, --rename and'
	Print_Message '--extension. Unknown words become literal names. Lists are joined'
	Print_Message 'with + or , (e.g. --dirs=year+month --subdirs=format,size).'
	printf '\n'
	Print_Message 'Date and file times:'
	printf '\t%s\n' 'year month day year+month year+month+day'
	printf '\t%s\n' 'created modified accessed'
	printf '\n'
	Print_Message 'File identity:'
	printf '\t%s\n' 'extension mime (text/plain) mime-main (TEXT) mime-sub (plain)'
	printf '\t%s\n' 'mime-ext (jpg - best matching extension for the MIME type)'
	printf '\t%s\n' 'compressed (main dir / single file inside an archive)'
	printf '\t%s\n' 'md5|md5sum sha1 sha224 sha256 sha384 sha512 sha|shasum b2 crc32'
	printf '\t%s\n' 'random randomN (N concatenated random values, e.g. random3)'
	printf '\n'
	Print_Message 'Size and media dimensions:'
	printf '\t%s\n' 'size        images/videos: WxH - others: human size (4.0M)'
	printf '\t%s\n' 'format      images/videos: TIER/ORIENTATION - others: unit name'
	printf '\t%s\n' 'size+format / format+size   both, in either order'
	printf '\t%s\n' 'duration    videos: HH-MM-SS'
	printf '\n'
	Print_Message 'Resolution tiers use the larger dimension:'
	printf '\t%s\n' 'TINY <64, MINI <128, SMALLER <320, SMALL <640, MEDIUM <1280,'
	printf '\t%s\n' 'BIG <1920, BIGGER <3840, HUGE otherwise'
	printf '\t%s\n' 'Orientation: SQUARE (w=h), WIDE (w>h), HIGH (h>w)'
	printf '\n'
	Print_Message 'Metadata (needs exiftool):'
	printf '\t%s\n' 'camera      EXIF camera as directory tag'
	printf '\t%s\n' 'exifdate    EXIF capture date as YYYY-MM-DD'
	printf '\t%s\n' 'title       embedded title (PDF /Title, media tags, EXIF date)'
	printf '\n'
	Print_Header 'Examples' '='
	printf '\t%s\n' 'Sort.sh --dirs=mime-main --type=image ./Downloads/*'
	printf '\t%s\n' 'Sort.sh --mode=move --dirs=year+month --title --type=video ~/V'
	printf '\t%s\n' 'Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg'
	printf '\t%s\n' 'Sort.sh --mode=trash --recursive --type=audio --pause=1 ~/Music'
	printf '\n'
	Print_Message 'Missing tools are proposed for install on first use (init-system).'
}

# ---------------------------------------------------------------------------
# Argument parsing - options first, everything else becomes a file argument
# ---------------------------------------------------------------------------

Parse_Arguments() {
	local Item

	for Item in "$@"; do
		case "$Item" in
		--copy | --mode=copy)
			Modus='Copy'
			;;
		--move | --mode=move)
			Modus='Move'
			;;
		--remove | --delete | --mode=remove | --mode=delete)
			Modus='Remove'
			;;
		--trash | --mode=trash)
			Modus='Trash'
			;;
		--shred | --mode=shred)
			Modus='Shred'
			;;
		--mode=dummy | --mode=print)
			Modus='Print'
			;;
		--mode=*)
			Modus=${Item#--mode=}
			Modus=${Modus,,}
			Modus=${Modus^}
			;;
		--replace)
			Replace='Yes'
			;;
		--type=*)
			Type_Filter=${Item#--type=}
			;;
		--recursive)
			Recursive=1
			;;
		--hidden)
			Hidden=1
			;;
		--links)
			Links=1
			;;
		--pause=*)
			Pause=${Item#--pause=}
			;;
		--pause)
			Pause=1
			;;
		--target=*)
			Target_Dir=${Item#--target=}
			;;
		--dirs=*)
			Dirs_Spec=${Item#--dirs=}
			;;
		--subdirs=*)
			SubDirs_Spec=${Item#--subdirs=}
			;;
		--rename=*)
			Rename=${Item#--rename=}
			;;
		--extension=*)
			Append=${Item#--extension=}
			;;
		--title)
			Title_Mode=1
			;;
		--exif)
			Use_EXIF=1
			;;
		--strip)
			Strip=1
			;;
		--decompress)
			Decompress=1
			;;
		--colored | --colors)
			Color_Enable
			;;
		--quiet)
			Quiet=1
			;;
		--verbose)
			Quiet=0
			;;
		--stats)
			:
			;;
		--log=*)
			LogFile=${Item#--log=}
			;;
		--undo=*)
			UndoFile=${Item#--undo=}
			;;
		--undo)
			UndoFile="./sort_undo_$(date +%Y%m%d_%H%M%S).sh"
			;;
		--jobs=*)
			Max_Jobs=${Item#--jobs=}
			[ "$Max_Jobs" -ge 1 ] 2>/dev/null || Max_Jobs=1
			;;
		--usage)
			Usage
			exit 0
			;;
		--help | -h)
			Help
			exit 0
			;;
		--version)
			printf 'Sort 17.0\n'
			exit 0
			;;
		--)
			shift
			;;
		-*)
			Print_Warning "Unknown option: $Item (ignored)"
			;;
		*)
			Files+=("$Item")
			;;
		esac
	done
}

# ---------------------------------------------------------------------------
# Option validation - fail fast on impossible combinations
# ---------------------------------------------------------------------------

Validate_Options() {
	case "$Modus" in
	Print | Copy | Move | Remove | Trash | Shred) ;;
	*)
		Print_Error "Unsupported mode: $Modus"
		return 1
		;;
	esac

	if [ -n "$Pause" ] && ! [[ "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		Print_Error "Invalid --pause value: $Pause"
		return 1
	fi

	if [ "$Modus" = 'Shred' ] && ! command -v shred >/dev/null; then
		Print_Error '--mode=shred requires shred (coreutils)'
		return 1
	fi

	mkdir -p -- "$Target_Dir" || {
		Print_Error "Cannot create target directory: $Target_Dir"
		return 1
	}
}

# ---------------------------------------------------------------------------
# File collection - build the array of files to treat at the beginning
# ---------------------------------------------------------------------------

Collect_Files() {
	local Item File StartBase
	local -a Dir_Args

	for Item in "${Files[@]}"; do
		if [ -d "$Item" ]; then
			# Depth: full walk with --recursive, top level only otherwise
			Dir_Args=()
			[ "$Recursive" -eq 1 ] || Dir_Args+=(-maxdepth 1)

			# Hidden entries are pruned unless --hidden; the start point
			# itself (which may be named .* too) must never be pruned
			if [ "$Hidden" -eq 0 ]; then
				StartBase=${Item##*/}
				[ -n "$StartBase" ] || StartBase=$Item
				Dir_Args+=(-name '.*' ! -path "$Item" ! -name "$StartBase" -prune -o)
			fi

			# Regular files, plus symlinks with --links
			if [ "$Links" -eq 1 ]; then
				Dir_Args+=(\( -type f -o -type l \) -print0)
			else
				Dir_Args+=(-type f -print0)
			fi

			while IFS= read -r -d '' File; do
				Targets+=("$File")
			done < <(find "$Item" "${Dir_Args[@]}" 2>/dev/null)
		elif [ -f "$Item" ] || { [ "$Links" -eq 1 ] && [ -L "$Item" ]; }; then
			Targets+=("$Item")
		else
			Print_Warning "Not a file or directory: $Item"
		fi
	done

	[ "$Quiet" -eq 1 ] || Print_Info "Files to treat: ${#Targets[@]}"
}

# ---------------------------------------------------------------------------
# Dynamic-value engine - one resolver for every keyword
# ---------------------------------------------------------------------------

# Make a string safe as a directory/file name (camera names, titles)
Sanitize_Name() {
	local String=${1// /_}

	printf '%s' "$String" | tr -d '/\\:*?"<>|'
}

# Resolution tier from a WxH string, by the larger dimension
Media_Tier() {
	local WxH=$1 W=${1%x*} H=${1#*x} Big

	if [ "$W" -ge "$H" ] 2>/dev/null; then Big=$W; else Big=$H; fi

	if [ "$Big" -lt 64 ]; then
		printf 'TINY'
	elif [ "$Big" -lt 128 ]; then
		printf 'MINI'
	elif [ "$Big" -lt 320 ]; then
		printf 'SMALLER'
	elif [ "$Big" -lt 640 ]; then
		printf 'SMALL'
	elif [ "$Big" -lt 1280 ]; then
		printf 'MEDIUM'
	elif [ "$Big" -lt 1920 ]; then
		printf 'BIG'
	elif [ "$Big" -lt 3840 ]; then
		printf 'BIGGER'
	else
		printf 'HUGE'
	fi
}

# Orientation from a WxH string: SQUARE / WIDE / HIGH
Media_Orient() {
	local WxH=$1 W=${1%x*} H=${1#*x}

	if [ "$W" = "$H" ]; then
		printf 'SQUARE'
	elif [ "$W" -gt "$H" ] 2>/dev/null; then
		printf 'WIDE'
	else
		printf 'HIGH'
	fi
}

# Decimal unit name from the file size: Byte / Kilo / Mega / Giga / Tera
Size_Unit_Name() {
	local Size

	Size=$(Get_File_Size "$1") || return 1

	if [ "$Size" -lt 1024 ]; then
		printf 'Byte'
	elif [ "$Size" -lt 1048576 ]; then
		printf 'Kilo'
	elif [ "$Size" -lt 1073741824 ]; then
		printf 'Mega'
	elif [ "$Size" -lt 1099511627776 ]; then
		printf 'Giga'
	else
		printf 'Tera'
	fi
}

# EXIF capture date as a YYYY-MM-DD tag, empty when unusable
Exif_Date_Dir() {
	local Date Dir

	Date=$(Get_EXIF_Date "$1" 2>/dev/null) || return 1
	Dir=${Date%% *}
	Dir=${Dir//:/-}

	[[ "$Dir" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
	printf '%s' "$Dir"
}

# EXIF camera as a directory tag, empty when unreadable
Exif_Camera_Dir() {
	local Cam

	Cam=$(Get_EXIF_Camera "$1" 2>/dev/null) || return 1
	Cam=$(Sanitize_Name "$Cam")
	[ -n "$Cam" ] || return 1
	printf '%s' "$Cam"
}

# Embedded metadata title: PDF /Title, image EXIF date, audio/video tags
Title_Name() {
	local File=$1 Main=$2 T A Al

	case "$Main" in
	application)
		Get_Doc_Title "$File"
		;;
	image)
		if ! T=$(Exif_Date_Dir "$File"); then
			T=$(stat -c %y -- "$File" 2>/dev/null)
			T=$(date -d "${T%%.*}" +%Y-%m-%d 2>/dev/null)
		fi
		[ -n "$T" ] && printf '%s' "$T" || Get_File_Name "$File"
		;;
	audio)
		A=$(Get_Media_Artist "$File" 2>/dev/null)
		Al=$(Get_Media_Album "$File" 2>/dev/null)
		T=$(Get_Media_Title "$File" 2>/dev/null)
		T=$(printf '%s_%s_%s' "${A:-}" "${Al:-}" "${T:-}" | sed 's/_\+/_/g; s/^_//; s/_$//')
		[ -n "$T" ] && printf '%s' "$T" || Get_File_Name "$File"
		;;
	video)
		A=$(Get_Media_Artist "$File" 2>/dev/null)
		T=$(Get_Media_Title "$File" 2>/dev/null)
		T=$(printf '%s_%s' "${A:-}" "${T:-}" | sed 's/_\+/_/g; s/^_//; s/_$//')
		[ -n "$T" ] && printf '%s' "$T" || Get_File_Name "$File"
		;;
	*)
		Get_File_Name "$File"
		;;
	esac
}

# Resolve one dynamic keyword for a file.
# Prints the value; rc 0 = resolved, rc 1 = failed (tool missing), rc 2 = unknown keyword.
Resolve_Segment() {
	local Key=${1,,} File=$2 Mime=$3 Main=$4
	local Ts T WxH N Out Folder

	case "$Key" in
	# Date and file times
	year | month | day | year+month | year+month+day)
		Ts=$(stat -c %w -- "$File" 2>/dev/null)
		[[ -z "$Ts" || "$Ts" == '-'* ]] && Ts=$(stat -c %y -- "$File" 2>/dev/null)
		case "$Key" in
		year)
			date -d "${Ts%%.*}" +%Y 2>/dev/null || printf '0000'
			;;
		month)
			date -d "${Ts%%.*}" +%m 2>/dev/null || printf '00'
			;;
		day)
			date -d "${Ts%%.*}" +%d 2>/dev/null || printf '00'
			;;
		year+month)
			date -d "${Ts%%.*}" +%Y/%m 2>/dev/null || printf '0000/00'
			;;
		year+month+day)
			date -d "${Ts%%.*}" +%Y/%m/%d 2>/dev/null || printf '0000/00/00'
			;;
		esac
		;;
	created)
		stat -c %w -- "$File" 2>/dev/null | sed 's/\..*//; s/ /_/'
		;;
	modified)
		stat -c %y -- "$File" 2>/dev/null | sed 's/\..*//; s/ /_/'
		;;
	accessed)
		stat -c %x -- "$File" 2>/dev/null | sed 's/\..*//; s/ /_/'
		;;

	# File identity
	extension)
		local CExt
		CExt=$(Get_Compound_Ext "$File") || CExt=$(Get_File_Ext "$File")
		printf '%s' "$CExt"
		;;
	compressed)
		local CName
		CName=$(Archive_Main_Name "$File") || CName=$(Get_File_Name "$File")
		printf '%s' "$CName"
		;;
	mime-ext)
		local MExt Rc
		MExt=$(Get_MIME_Best_Extension "$File")
		Rc=$?
		if [ "$Rc" -eq 0 ] && [ -n "$MExt" ]; then
			printf '%s' "$MExt"
		else
			return 1
		fi
		;;
	mime)
		printf '%s' "$Mime"
		;;
	mime-main)
		printf '%s' "${Main^^}"
		;;
	mime-sub)
		printf '%s' "${Mime#*/}"
		;;

	# Checksums
	md5 | md5sum)
		Get_MD5Sum "$File"
		;;
	sha1 | sha1sum)
		Get_SHA1Sum "$File"
		;;
	sha224 | sha224sum)
		Get_SHA224Sum "$File"
		;;
	sha256 | sha256sum)
		Get_SHA256Sum "$File"
		;;
	sha384 | sha384sum)
		Get_SHA384Sum "$File"
		;;
	sha512 | sha512sum)
		Get_SHA512Sum "$File"
		;;
	sha | shasum)
		Get_SHA256Sum "$File"
		;;
	b2 | blake2)
		Get_B2Sum "$File"
		;;
	crc32 | cksum)
		Get_CRC32 "$File"
		;;

	# Random
	random)
		printf '%s' "$RANDOM"
		;;
	random[0-9]*)
		N=${Key#random}
		Out=''
		while [ "$N" -gt 0 ] 2>/dev/null; do
			Out="$Out$RANDOM"
			N=$((N - 1))
		done
		printf '%s' "$Out"
		;;

	# Size and media dimensions
	size)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] && printf '%s' "$WxH" || return 1
		else
			Get_File_Size_Human "$File"
		fi
		;;
	format)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] || return 1
			printf '%s/%s' "$(Media_Tier "$WxH")" "$(Media_Orient "$WxH")"
		else
			Size_Unit_Name "$File"
		fi
		;;
	size+format)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] || return 1
			printf '%s/%s/%s' "$WxH" "$(Media_Tier "$WxH")" "$(Media_Orient "$WxH")"
		else
			printf '%s/%s' "$(Get_File_Size_Human "$File")" "$(Size_Unit_Name "$File")"
		fi
		;;
	format+size)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] || return 1
			printf '%s/%s/%s' "$(Media_Tier "$WxH")" "$(Media_Orient "$WxH")" "$WxH"
		else
			printf '%s/%s' "$(Size_Unit_Name "$File")" "$(Get_File_Size_Human "$File")"
		fi
		;;
	duration)
		Video_Duration_Tag "$File"
		;;

	# Metadata
	camera)
		Exif_Camera_Dir "$File"
		;;
	exifdate)
		Exif_Date_Dir "$File"
		;;
	title)
		Title_Name "$File" "$Main"
		;;

	# Name helpers (for --rename)
	long | base)
		Get_File_Base "$File"
		;;
	short | name)
		Get_Base_Name "$File"
		;;
	folder)
		local Folder
		Folder=$(Get_File_Dir "$File")
		Folder=${Folder##*/}
		[ "$Folder" = '.' ] && Folder=''
		[ -n "$Folder" ] && printf '%s' "$Folder" || return 1
		;;
	folder_name | foldername)
		local Folder
		Folder=$(Get_File_Dir "$File")
		Folder=${Folder##*/}
		[ "$Folder" = '.' ] && Folder=''
		if [ -n "$Folder" ]; then
			printf '%s_%s' "$Folder" "$(Get_Base_Name "$File")"
		else
			Get_Base_Name "$File"
		fi
		;;

	*)
		return 2
		;;
	esac
}

# Build a /-joined path from a segment list; unknown keywords become literals.
# Build_Segments <spec> <file> <mime> <main>
Build_Segments() {
	local Spec=$1 File=$2 Mime=$3 Main=$4
	local Key Seg Out='' Rc

	Spec=${Spec//+/,}
	IFS=',' read -ra Keys <<<"$Spec"

	for Key in "${Keys[@]}"; do
		Key=${Key// /}
		[ -n "$Key" ] || continue

		Seg=$(Resolve_Segment "$Key" "$File" "$Mime" "$Main")
		Rc=$?
		[ "$Rc" -eq 2 ] && Seg=$Key
		[ "$Rc" -le 1 ] && [ -n "$Seg" ] && Out="$Out/$Seg"
	done

	printf '%s' "${Out#/}"
}

# ---------------------------------------------------------------------------
# Name / extension builders - driven by --rename, --title and --extension
# ---------------------------------------------------------------------------

Build_Name() {
	local File=$1 Mime=$2 Main=$3 Name Rc

	if [ "$Title_Mode" -eq 1 ] && [ -z "$Rename" ]; then
		Sanitize_Name "$(Title_Name "$File" "$Main")"
		return 0
	fi

	case "$Rename" in
	'')
		Name=$(Resolve_Segment folder_name "$File" "$Mime" "$Main")
		[ -n "$Name" ] && printf '%s' "$Name" || Get_Base_Name "$File"
		;;
	*)
		Name=$(Resolve_Segment "$Rename" "$File" "$Mime" "$Main")
		Rc=$?
		if [ "$Rc" -eq 2 ]; then
			printf '%s' "$Rename"
		elif [ "$Rc" -eq 0 ] && [ -n "$Name" ]; then
			Sanitize_Name "$Name"
		else
			return 1
		fi
		;;
	esac
}

# File name without ANY extension - a compound suffix (.tar.gz) counts as one.
# Get_Base_Name <file>
Get_Base_Name() {
	local Base=${1##*/}
	local Suffix

	if Suffix=$(Get_Compound_Ext "$1"); then
		printf '%s' "${Base%."$Suffix"}"
	else
		Get_File_Name "$1"
	fi
}

# Compound extension: dotted suffixes like .tar.gz / .tar.bz2 / .TAR.GZ count
# as ONE extension. Get_Compound_Ext <file>   (stdout: suffix; rc 1 = none)
Get_Compound_Ext() {
	local Base=${1##*/}
	local Low=${Base,,}
	local Comp

	local Suffix

	for Comp in .tar.gz .tgz .tar.bz2 .tbz2 .tbz .tar.xz .txz .tar.zst .tzst .tar.lzma .tar.lz; do
		if [[ "$Low" == *"$Comp" ]]; then
			Suffix=${Base: -${#Comp}}
			printf '%s' "${Suffix#.}"
			return 0
		fi
	done

	return 1
}

Build_Extension() {
	local File=$1 Mime=$2 Ext Rc

	case "$Append" in
	'')
		Ext=$(Get_Compound_Ext "$File") || Ext=$(Get_File_Ext "$File")
		[ -n "$Ext" ] && printf '.%s' "$Ext"
		;;
	none)
		printf ''
		;;
	mime)
		printf '.%s' "${Mime//\//.}"
		;;
	mime-sub)
		printf '.%s' "${Mime#*/}"
		;;
	*)
		Ext=$(Resolve_Segment "$Append" "$File" "$Mime" "${Mime%%/*}")
		Rc=$?
		if [ "$Rc" -eq 2 ]; then
			printf '.%s' "$Append"
		elif [ "$Rc" -eq 0 ] && [ -n "$Ext" ]; then
			printf '.%s' "$Ext"
		else
			Ext=$(Get_Compound_Ext "$File") || Ext=$(Get_File_Ext "$File")
			[ -n "$Ext" ] && printf '.%s' "$Ext"
		fi
		;;
	esac
}

# ---------------------------------------------------------------------------
# Optional output - the log file and the undo script
# ---------------------------------------------------------------------------

Prepare_Optional_Output() {
	if [ -n "$LogFile" ]; then
		mkdir -p -- "$(dirname -- "$LogFile")" 2>/dev/null
		printf '# Sort 17.0 log started at %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LogFile"
	fi
	if [ -n "$UndoFile" ]; then
		{
			printf '#!/usr/bin/env bash\n'
			printf '# Undo script generated by Sort 17.0 at %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
			printf '# Run this script to reverse the copy/move actions.\n'
		} >"$UndoFile"
	fi
}

# One line per action into the log file (atomic appends from parallel jobs)
Log_Action() {
	[ -n "$LogFile" ] || return 0
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LogFile"
}

# One inverse command per action into the undo script
Undo_Action() {
	[ -n "$UndoFile" ] || return 0
	printf '%s\n' "$*" >>"$UndoFile"
}

# ---------------------------------------------------------------------------
# Per-file worker - classify, build the target, then act
# Sets Status for the tally.
# ---------------------------------------------------------------------------

# Strip EXIF/GPS metadata from a target in place (needs exiftool or ImageMagick)
Strip_Target() {
	local Target=$1 Tmp

	Tmp="$Target.strip.$$"

	if EXIF_Strip "$Target" "$Tmp"; then
		mv -f -- "$Tmp" "$Target"
		[ "$Quiet" -eq 1 ] || Print_Info "Stripped metadata: $Target"
	else
		rm -f -- "$Tmp"
		Print_Warning "Could not strip metadata: $Target"
	fi
}

# Aspect form from a WxH string: Square / Portrait / Landscape
Image_Form() {
	local WxH=$1 W=${1%x*} H=${1#*x}

	if [ "$W" = "$H" ]; then
		printf 'Square'
	elif [ "$H" -gt "$W" ] 2>/dev/null; then
		printf 'Portrait'
	else
		printf 'Landscape'
	fi
}

# Duration as a filename-safe HH-MM-SS tag
Video_Duration_Tag() {
	local Seconds H M S

	Seconds=$(Get_Duration "$1") || return 1
	Seconds=${Seconds%.*}
	Seconds=${Seconds:-0}

	H=$((Seconds / 3600))
	M=$(((Seconds % 3600) / 60))
	S=$((Seconds % 60))

	printf '%02d-%02d-%02d' "$H" "$M" "$S"
}

# Handle one archive under --decompress: test it, extract it into a temp dir,
# sort the extracted contents (always with copy semantics), then apply the
# mode to the archive itself: preview / delete / trash / shred.
# Process_Archive <file>
Process_Archive() {
	local File=$1
	local Tmp SavedModus Count=0 Inner

	Status='FAILED'

	[ "$Decompress_Depth" -lt 8 ] || {
		Print_Error "Decompression too deep: $File"
		return 1
	}

	# Extract + test: a failing archive is never touched further
	Archive_Test "$File" || {
		Print_Error "Archive test failed: $File"
		return 1
	}

	Tmp=$(mktemp -d) || return 1
	Archive_Extract "$File" "$Tmp" || {
		Print_Error "Extract failed: $File"
		rm -rf -- "$Tmp"
		return 1
	}

	# In action modes the contents are always sorted with copy semantics; the
	# mode only decides the fate of the archive itself. Preview stays preview.
	SavedModus=$Modus
	case "$Modus" in
	Print) ;;
	*) Modus='Copy' ;;
	esac

	while IFS= read -r -d '' Inner; do
		Decompress_Depth=$((Decompress_Depth + 1))
		Process_File "$Inner"
		Decompress_Depth=$((Decompress_Depth - 1))
		Count=$((Count + 1))
	done < <(find "$Tmp" -mindepth 1 -type f -print0 | sort -z)

	Modus=$SavedModus
	rm -rf -- "$Tmp"

	# Fate of the archive itself
	case "$Modus" in
	Print)
		Status='PREVIEW'
		Print_Message "EXTRACT($Count): $File <=> delete archive"
		;;
	Trash)
		Deps_Ensure trash-put || {
			Status='FAILED'
			Print_Error 'Trash needs trash-put (trash-cli)'
			return 1
		}
		if trash-put -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "Extracted($Count) + trashed: $File"
			Log_Action "TRASH $File"
		else
			Status='FAILED'
			Print_Error "Trash failed: $File"
			return 1
		fi
		;;
	Shred)
		if shred -u -n 1 -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "Extracted($Count) + shredded: $File"
			Log_Action "SHRED $File"
		else
			Status='FAILED'
			Print_Error "Shred failed: $File"
			return 1
		fi
		;;
	*)
		if rm -v -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "Extracted($Count) + deleted: $File"
			Log_Action "DELETE $File"
		else
			Status='FAILED'
			Print_Error "Delete failed: $File"
			return 1
		fi
		;;
	esac

	return 0
}

Process_File() {
	local File=$1
	local Mime Main DirPart SubPart NewDir Name Ext New Count=0
	local SourceReal TargetReal

	Status='FAILED'

	[ -f "$File" ] || [ -L "$File" ] || {
		Print_Error "Not a regular file: $File"
		return 1
	}

	# MIME type drives everything; no type -> no destination
	Mime=$(Get_MIME_Type "$File") || {
		Print_Error "No MIME type for: $File"
		return 1
	}
	Main=${Mime%%/*}

	# --type filter: the value must occur in the MIME type
	if [ -n "$Type_Filter" ] && [[ "${Mime,,}" != *"${Type_Filter,,}"* ]]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "Type skip ($Mime): $File"
		return 0
	fi

	# --decompress: archives are extracted first and their contents sorted
	if [ "$Decompress" -eq 1 ] && Archive_Is "$File"; then
		Process_Archive "$File"
		return $?
	fi

	# Primary directory: --dirs= segments, or the MIME type by default
	if [ -n "$Dirs_Spec" ]; then
		DirPart=$(Build_Segments "$Dirs_Spec" "$File" "$Mime" "$Main")
	else
		DirPart="$Mime"
	fi

	# Secondary directory: --subdirs= segments, or per-kind defaults
	if [ -n "$SubDirs_Spec" ]; then
		SubPart=$(Build_Segments "$SubDirs_Spec" "$File" "$Mime" "$Main")
	else
		case "$Main" in
		image)
			local WxH
			WxH=$(Get_Image_WxH "$File") || WxH='unknown'
			SubPart="$(Image_Form "$WxH")/$WxH"

			# With --exif, images with EXIF gain <Camera>/<YYYY-MM-DD> levels
			if [ "$Use_EXIF" -eq 1 ]; then
				local Cam DateDir
				Cam=$(Exif_Camera_Dir "$File") || Cam=''
				DateDir=$(Exif_Date_Dir "$File") || DateDir=''

				local Pre=''
				[ -n "$Cam" ] && Pre="$Cam"
				[ -n "$DateDir" ] && Pre="${Pre:+$Pre/}$DateDir"
				[ -n "$Pre" ] && SubPart="$Pre/$SubPart"

				if [ "$Quiet" -eq 0 ] && [ -n "$Cam$DateDir" ]; then
					Print_Info "EXIF: ${Cam:-unknown camera} ${DateDir:-unknown date}"
				fi
			fi
			;;
		video)
			local WxH Dur
			WxH=$(Get_Media_WxH "$File") || WxH='unknown'
			Dur=$(Video_Duration_Tag "$File") || Dur='unknown'
			SubPart="$WxH/$Dur"
			;;
		*)
			local Unit
			Unit=$(Size_Unit_Name "$File")
			[ "$Unit" = 'Byte' ] || Unit="${Unit}Byte"
			SubPart="$Unit/$(Get_File_Size_Human "$File")"
			;;
		esac
	fi

	NewDir="${Target_Dir#./}/${DirPart:+$DirPart/}$SubPart"
	NewDir=${NewDir#./}

	# New name and extension
	Name=$(Build_Name "$File" "$Mime" "$Main") || {
		Print_Error "Cannot build a name for: $File"
		return 1
	}
	Ext=$(Build_Extension "$File" "$Mime")

	mkdir -p -- "$NewDir" || {
		Print_Error "Cannot create: $NewDir"
		return 1
	}
	New="$NewDir/$Name$Ext"

	# Without --replace, never clobber: slide a ~(N) counter in.
	# Destructive modes act on the calculated target as-is, no counter.
	if [ ! "$Replace" = 'Yes' ]; then
		case "$Modus" in
		Remove | Trash | Shred) ;;
		*)
			while [ -e "$New" ]; do
				Count=$((Count + 1))
				New="$NewDir/$Name~($Count)$Ext"
			done
			;;
		esac
	fi

	# Already in place -> nothing to do
	SourceReal=$(realpath -- "$File" 2>/dev/null)
	TargetReal=$(realpath -m -- "$New" 2>/dev/null)
	if [ -n "$SourceReal" ] && [ "$SourceReal" = "$TargetReal" ]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "Same place: $File"
		return 0
	fi

	# Act according to the mode
	case "$Modus" in
	Copy)
		if cp -v -- "$File" "$New"; then
			Status='COPIED'
			Print_Ok "$File -> $New"
			Log_Action "COPY $File -> $New"
			Undo_Action "rm -f -- '$(printf "%s" "$New" | sed "s/'/'\\\\''/g")'"
			[ "$Strip" -eq 1 ] && Strip_Target "$New"
		else
			Print_Error "Copy failed: $File"
			return 1
		fi
		;;
	Move)
		if mv -v -- "$File" "$New"; then
			Status='MOVED'
			Print_Ok "$File -> $New"
			Log_Action "MOVE $File -> $New"
			Undo_Action "mv -f -- '$(printf "%s" "$New" | sed "s/'/'\\\\''/g")' '$(printf "%s" "$File" | sed "s/'/'\\\\''/g")'"
			[ "$Strip" -eq 1 ] && Strip_Target "$New"
		else
			Print_Error "Move failed: $File"
			return 1
		fi
		;;
	Remove)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "Remove: target not found: $New"
			return 1
		fi
		if rm -v -- "$New"; then
			Status='REMOVED'
			Print_Ok "Removed: $New"
			Log_Action "REMOVE $New"
		else
			Print_Error "Remove failed: $New"
			return 1
		fi
		;;
	Trash)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "Trash: target not found: $New"
			return 1
		fi
		Deps_Ensure trash-put || {
			Print_Error 'Trash needs trash-put (trash-cli)'
			return 1
		}
		if trash-put -- "$New"; then
			Status='TRASHED'
			Print_Ok "Trashed: $New"
			Log_Action "TRASH $New"
		else
			Print_Error "Trash failed: $New"
			return 1
		fi
		;;
	Shred)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "Shred: target not found: $New"
			return 1
		fi
		if shred -u -n 1 -- "$New"; then
			Status='SHREDDED'
			Print_Ok "Shredded: $New"
			Log_Action "SHRED $New"
		else
			Print_Error "Shred failed: $New"
			return 1
		fi
		;;
	*)
		Status='PREVIEW'
		Print_Message "$File <=> $New"
		;;
	esac

	# Optional pause after each file
	[ "$Pause" -gt 0 ] 2>/dev/null && sleep "$Pause"

	return 0
}

# ---------------------------------------------------------------------------
# Threading - run the worker over the array with a bounded job pool
# Each job writes its own output and status tag, so lines never interleave.
# ---------------------------------------------------------------------------

Run_Threads() {
	local Tmp Idx=0 Total=$#
	local -i Done_Copied=0 Done_Moved=0 Done_Preview=0 Done_Skipped=0 Done_Failed=0 Done_Other=0 Done_Extracted=0

	Tmp=$(mktemp -d) || return 1

	# Launch every file, keeping at most Max_Jobs running at once
	while [ "$Idx" -lt "$Total" ]; do
		while [ "$(jobs -rp | wc -l)" -ge "$Max_Jobs" ]; do
			wait -n || true
		done

		(
			Process_File "${@:$((Idx + 1)):1}"
			printf '%s\n' "$Status" >"$Tmp/tag.$Idx"
		) >"$Tmp/out.$Idx" 2>&1 &

		Idx=$((Idx + 1))
	done
	wait

	# Report in submission order so the log stays readable
	for Idx in $(seq 0 $((Total - 1))); do
		[ "$Quiet" -eq 1 ] || cat "$Tmp/out.$Idx"

		case "$(cat "$Tmp/tag.$Idx" 2>/dev/null)" in
		COPIED) Done_Copied+=1 ;;
		MOVED) Done_Moved+=1 ;;
		PREVIEW) Done_Preview+=1 ;;
		SKIPPED) Done_Skipped+=1 ;;
		REMOVED | TRASHED | SHREDDED) Done_Other+=1 ;;
		EXTRACTED) Done_Extracted+=1 ;;
		*) Done_Failed+=1 ;;
		esac
	done

	rm -rf -- "$Tmp"

	# Summary
	printf '\n'
	Print_Header 'Summary'
	Print_Message "Copied : $Done_Copied"
	Print_Message "Moved  : $Done_Moved"
	Print_Message "Removed: $Done_Other"
	Print_Message "Extracted: $Done_Extracted"
	Print_Message "Preview: $Done_Preview"
	Print_Message "Skipped: $Done_Skipped"
	[ "$Done_Failed" -eq 0 ] && Print_Ok "Failed : $Done_Failed" || Print_Error "Failed : $Done_Failed"

	[ "$Done_Failed" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Interrupt handling - the system helpers wait for the running jobs,
# restore IFS and exit 130
# ---------------------------------------------------------------------------

trap Break INT

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Main() {
	local Rc

	# No arguments at all: show the short usage
	if [ $# -eq 0 ]; then
		Usage
		return 0
	fi

	Parse_Arguments "$@"

	# The --title sugar doubles as --rename=title when no rename was given
	Validate_Options || return 1

	# Init-system: one batch install proposal for the optional tools
	# (exiftool joins when EXIF or metadata-title features are requested)
	if [ "$Quiet" -eq 0 ]; then
		if [ "$Use_EXIF" -eq 1 ] || [ "$Strip" -eq 1 ] || [ "$Title_Mode" -eq 1 ] || [ "$Rename" = 'title' ] || [ -n "$UndoFile" ]; then
			Deps_Init identify ffprobe exiftool || true
		else
			Deps_Init identify ffprobe || true
		fi
		if [ "$Decompress" -eq 1 ]; then
			Deps_Init tar gzip unzip zip bzip2 xz zstd 7z unrar || true
		fi
	fi

	Prepare_Optional_Output

	# The array of files to treat, built before any work starts
	Collect_Files

	if [ "${#Targets[@]}" -eq 0 ]; then
		Print_Warning 'Nothing to treat.'
		return 1
	fi

	if [ "$Quiet" -eq 0 ]; then
		Draw_Line '='
		Print_Header "Sorting ${#Targets[@]} file(s) - mode: $Modus, jobs: $Max_Jobs"
	fi

	Run_Threads "${Targets[@]}"
	Rc=$?

	# Make the undo script executable when one was written
	[ -n "$UndoFile" ] && [ -f "$UndoFile" ] && chmod +x -- "$UndoFile"

	return $Rc
}

Main "$@"
Rc=$?

echo "Thanks for using HEjder scripts!"
exit $Rc
