#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V19.sh                                                           #
# Version : 19                                                              #
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
	printf '%s%s%s\n' "$C_WHITE" "$(T "$*")" "$C_RESET"
}

# Informational message on stdout (cyan).
Print_Info() {
	printf '%s%s%s\n' "$C_CYAN" "$(T "$*")" "$C_RESET"
}

# Success message on stdout (green).
Print_Ok() {
	printf '%s%s%s\n' "$C_GREEN" "$(T "$*")" "$C_RESET"
}

# Error message on stderr (red, "Error: " prefix). Returns false so it can
# be used directly as a failure statement.
Print_Error() {
	printf '%s%s%s%s\n' "$C_RED" "$(T 'Error: ')" "$*" "$C_RESET" >&2
	return 1
}

# Warning message on stderr (yellow, "Warning: " prefix).
Print_Warning() {
	printf '%s%s%s%s\n' "$C_YELLOW" "$(T 'Warning: ')" "$*" "$C_RESET" >&2
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

	printf '%s\n' "$(T 'Waiting for background jobs to finish...')"
	wait

	# Restore the original shell field separator.
	IFS=$OIFS

	printf '%s\n' "$(T 'Finished.')"
	exit "$Status"
}

Break() {
	printf '\n%s\n' "$(T 'Terminated by user!')"
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
		printf '%s\n' "$(T 'deps: no supported package manager found')" >&2
		return 1
	}

	Priv=$(Deps_Priv) || {
		printf '%s\n' "$(T 'deps: no way to gain root (run as root or install sudo)')" >&2
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
		printf '%s\n' "$(Tf 'deps: proposed install: %s' "$*")" >&2

		# Ask for confirmation on a terminal; without one, only DEPS_YES=1 installs.
		if [ -t 0 ]; then
			printf '%s' "$(T 'deps: install now? [y/N] ')" >&2
			read -r Answer || Answer=""
		elif [ -e /dev/tty ]; then
			printf '%s' "$(T 'deps: install now? [y/N] ')" >&2
			read -r Answer 2>/dev/null </dev/tty || Answer=""
		else
			printf '%s\n' "$(T 'deps: not installed (set DEPS_YES=1 to install without asking)')" >&2
			return 1
		fi

		case "$Answer" in
		y | Y | yes | YES | Yes) ;;
		*)
			printf '%s\n' "$(T 'deps: skipped')" >&2
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
		printf '%s\n' "$(Tf "deps: '%s' is missing and its package name is unknown" "$Tool")" >&2
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

	printf '%s\n' "$(Tf 'deps: missing: %s' "${Missing[*]}")" >&2

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

# Human-readable size from a byte count - pure bash arithmetic, no du fork.
# Human_From_Bytes <bytes>
Human_From_Bytes() {
	local S=$1 Frac=0 U=0
	local -a Unit=('B' 'K' 'M' 'G' 'T')

	while [ "$S" -ge 1024 ] && [ "$U" -lt 4 ]; do
		Frac=$((S % 1024))
		S=$((S / 1024))
		U=$((U + 1))
	done
	if [ "$U" -eq 0 ]; then
		printf '%s%s' "$S" "${Unit[$U]}"
	else
		printf '%s.%s%s' "$S" "$((Frac * 10 / 1024))" "${Unit[$U]}"
	fi
}

# Human-readable size of a file (stat + arithmetic instead of du | cut).
# Get_File_Size_Human <file>
Get_File_Size_Human() {
	local Size

	Size=$(Get_File_Size "$1") || return 1
	Human_From_Bytes "$Size"
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

# Width, height and duration in ONE ffprobe call - "<WxH>|<HH-MM-SS>".
# Get_Media_Info <file>
Get_Media_Info() {
	local File=$1 Out W H WxH Dur

	# First use without ffprobe: propose the install, then fall back.
	command -v ffprobe >/dev/null 2>&1 ||
		{ declare -F Deps_Ensure >/dev/null 2>&1 && Deps_Ensure ffprobe; }

	Out=$(timeout 10s ffprobe \
		-v error \
		-select_streams v:0 \
		-show_entries stream=width,height:format=duration \
		-of default=noprint_wrappers=1:nokey=1 \
		-- "$File" 2>/dev/null) || {
		printf '0x0|unknown'
		return 1
	}

	# Lines: width, height, duration - flatten and read them back
	Out=${Out//$'\n'/ }
	read -r W H Dur <<<"$Out"

	if [[ "$W" =~ ^[0-9]+$ ]] && [[ "$H" =~ ^[0-9]+$ ]]; then
		WxH="${W}x${H}"
	else
		WxH='0x0'
	fi

	[[ "$Dur" =~ ^[0-9]+([.][0-9]+)?$ ]] || Dur=''
	[ -n "$Dur" ] && Dur=$(Duration_Tag_From_Seconds "$Dur") || Dur='unknown'

	printf '%s|%s' "$WxH" "$Dur"
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
# TAGS MODULE
# ===========================================================================

# Audio tags - ID3v1 (last 128 bytes) and ID3v2 (v2.2/v2.3/v2.4 frames) are
# read directly from the file bytes, no external tagger needed. Friendly
# getters fall back to exiftool via Exif_Field when the file carries no ID3
# tag (FLAC, Ogg, M4A, WMA...).

# ---------------------------------------------------------------------------
# ID3v1 - the fixed 128-byte tag at the end of the file
# ---------------------------------------------------------------------------

# True when the file ends with an ID3v1 tag.
# Id3v1_Present <file>
Id3v1_Present() {
	local File=$1 Tag

	[ -r "$File" ] || return 1
	Tag=$(tail -c 128 -- "$File" 2>/dev/null | head -c 3)
	[ "$Tag" = 'TAG' ]
}

# Genre name for an ID3v1 genre index (0-125: the 80 standard genres plus
# the Winamp extensions). Unknown or out-of-range indexes fail.
# Id3v1_Genre_Name <index>
Id3v1_Genre_Name() {
	local Idx=$1
	local -a G=(
		Blues 'Classic Rock' Country Dance Disco Funk Grunge 'Hip-Hop'
		Jazz Metal 'New Age' Oldies Other Pop 'R&B' Rap Reggae Rock Techno
		Industrial Alternative Ska 'Death Metal' Pranks Soundtrack
		'Euro-Techno' Ambient 'Trip-Hop' Vocal 'Jazz+Funk' Fusion Trance
		Classical Instrumental Acid House Game 'Sound Clip' Gospel Noise
		'Alternative Rock' Bass Soul Punk Space Meditation 'Instrumental Pop'
		'Instrumental Rock' Ethnic Gothic Darkwave 'Techno-Industrial'
		Electronic 'Pop-Folk' Eurodance Dream 'Southern Rock' Comedy Cult
		Gangsta 'Top 40' 'Christian Rap' 'Pop/Funk' Jungle 'Native US'
		Cabaret 'New Wave' Psychadelic Rave Showtunes Trailer 'Lo-Fi' Tribal
		'Acid Punk' 'Acid Jazz' Polka Retro Musical 'Rock & Roll' 'Hard Rock'
		Folk 'Folk-Rock' 'National Folk' Swing 'Fast Fusion' Bebob Latin
		Revival Celtic Bluegrass Avantgarde 'Gothic Rock' 'Progressive Rock'
		'Psychedelic Rock' 'Symphonic Rock' 'Slow Rock' 'Big Band' Chorus
		'Easy Listening' Acoustic Humour Speech Chanson Opera 'Chamber Music'
		Sonata Symphony 'Booty Bass' Primus 'Porn Groove' Satire 'Slow Jam'
		Club Tango Samba Folklore Ballad 'Power Ballad' 'Rhythmic Soul'
		Freestyle Duet 'Punk Rock' 'Drum Solo' 'A cappella' 'Euro-House'
		'Dance Hall'
	)

	[[ "$Idx" =~ ^[0-9]+$ ]] || return 1
	[ "$Idx" -lt "${#G[@]}" ] || return 1
	printf '%s' "${G[$Idx]}"
}

# One ID3v1 field by name: title artist album year comment track genre.
# Id3v1_Field <file> <field>
Id3v1_Field() {
	local File=$1 Field=${2,,} Raw
	local Skip Count
	local B125 B126 Idx

	[ -r "$File" ] || return 1
	Id3v1_Present "$File" || return 1

	case "$Field" in
	title) Skip=3 Count=30 ;;
	artist) Skip=33 Count=30 ;;
	album) Skip=63 Count=30 ;;
	year) Skip=93 Count=4 ;;
	comment) Skip=97 Count=28 ;;
	track)
		# Track byte only valid when the comment zero-separator is there
		B125=$(tail -c 128 -- "$File" 2>/dev/null | tail -c 3 | head -c 1 | od -An -tu1 | tr -d ' ')
		B126=$(tail -c 128 -- "$File" 2>/dev/null | tail -c 2 | head -c 1 | od -An -tu1 | tr -d ' ')
		if [ "$B125" = '0' ] && [ -n "$B126" ] && [ "$B126" != '0' ]; then
			printf '%s' "$B126"
			return 0
		fi
		return 1
		;;
	genre)
		Idx=$(tail -c 128 -- "$File" 2>/dev/null | tail -c 1 | od -An -tu1 | tr -d ' ')
		if [ -n "$Idx" ] && Id3v1_Genre_Name "$Idx"; then
			return 0
		fi
		[ -n "$Idx" ] && [ "$Idx" != '255' ] && printf '%s' "$Idx"
		return 0
		;;
	*)
		return 1
		;;
	esac

	Raw=$(tail -c 128 -- "$File" 2>/dev/null | tail -c +$((Skip + 1)) | head -c "$Count" | tr -d '\0')
	Raw="${Raw%"${Raw##*[! ]}"}"
	[ -n "$Raw" ] && printf '%s' "$Raw"
}

# ---------------------------------------------------------------------------
# ID3v2 - the frame-based tag at the start of the file (v2.2 / v2.3 / v2.4)
# ---------------------------------------------------------------------------

# True when the file starts with an ID3v2 tag.
# Id3v2_Present <file>
Id3v2_Present() {
	local File=$1 Magic

	[ -r "$File" ] || return 1
	Magic=$(head -c 3 -- "$File" 2>/dev/null)
	[ "$Magic" = 'ID3' ]
}

# ID3v2 major version (2, 3 or 4).
# Id3v2_Major <file>
Id3v2_Major() {
	local Ver

	[ -r "$1" ] || return 1
	Id3v2_Present "$1" || return 1
	Ver=$(head -c 4 -- "$1" 2>/dev/null | tail -c 1 | od -An -tu1 | tr -d ' ')
	[ -n "$Ver" ] && printf '%s' "$Ver"
}

# Total ID3v2 tag size in bytes (the synchsafe header size, header excluded).
# Id3v2_Tag_Size <file>
Id3v2_Tag_Size() {
	local File=$1 Bytes
	local B0 B1 B2 B3

	[ -r "$File" ] || return 1
	Id3v2_Present "$File" || return 1

	Bytes=$(head -c 10 -- "$File" 2>/dev/null | tail -c 4 | od -An -tu1 | tr -s ' \n' ' ')
	read -r B0 B1 B2 B3 <<<"$Bytes"
	[ -n "$B3" ] || return 1
	printf '%s' $(((B0 << 21) | (B1 << 14) | (B2 << 7) | B3))
}

# One ID3v2 text frame by 4-character id (v2.2 files take 3-character ids).
# Id3v2_Field <file> <frame>
Id3v2_Field() {
	local File=$1 Frame=$2
	local Ver TagSize Off End Hdr FSize FID Bytes B0 B1 B2 B3 Data Enc

	[ -r "$File" ] || return 1
	Id3v2_Present "$File" || return 1

	Ver=$(Id3v2_Major "$File")
	TagSize=$(Id3v2_Tag_Size "$File") || return 1
	Off=10
	End=$((10 + TagSize))

	while [ "$Off" -lt "$End" ]; do
		if [ "$Ver" = '2' ]; then
			# v2.2: 3-char frame id, 3-byte big-endian size, no flags
			FID=$(dd if="$File" bs=1 skip="$Off" count=3 2>/dev/null)
			[[ "$FID" =~ ^[A-Z0-9]{3}$ ]] || break
			Bytes=$(dd if="$File" bs=1 skip=$((Off + 3)) count=3 2>/dev/null | od -An -tu1 | tr -s ' \n' ' ')
			read -r B0 B1 B2 <<<"$Bytes"
			[ -n "$B2" ] || break
			FSize=$(((B0 << 16) | (B1 << 8) | B2))
			Hdr=6
		else
			FID=$(dd if="$File" bs=1 skip="$Off" count=4 2>/dev/null)
			[[ "$FID" =~ ^[A-Z0-9]{4}$ ]] || break
			Bytes=$(dd if="$File" bs=1 skip=$((Off + 4)) count=4 2>/dev/null | od -An -tu1 | tr -s ' \n' ' ')
			read -r B0 B1 B2 B3 <<<"$Bytes"
			[ -n "$B3" ] || break
			if [ "$Ver" -ge 4 ]; then
				# v2.4: synchsafe size
				FSize=$(((B0 << 21) | (B1 << 14) | (B2 << 7) | B3))
			else
				# v2.3: plain big-endian size
				FSize=$(((B0 << 24) | (B1 << 16) | (B2 << 8) | B3))
			fi
			Hdr=10
		fi
		[ "$FSize" -gt 0 ] 2>/dev/null || break

		if [ "$FID" = "$Frame" ]; then
			# First payload byte is the text encoding:
			# 0 = latin-1, 1 = UTF-16 with BOM, 2 = UTF-16BE, 3 = UTF-8
			Enc=$(dd if="$File" bs=1 skip=$((Off + Hdr)) count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
			case "$Enc" in
			1)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
					iconv -f UTF-16 -t UTF-8 2>/dev/null | tr -d '\0')
				if [ -z "$Data" ]; then
					Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
						iconv -f UTF-16LE -t UTF-8 2>/dev/null | tr -d '\0')
				fi
				;;
			2)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
					iconv -f UTF-16BE -t UTF-8 2>/dev/null | tr -d '\0')
				;;
			0)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
					iconv -f ISO-8859-1 -t UTF-8 2>/dev/null | tr -d '\0')
				;;
			*)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null | tr -d '\0')
				;;
			esac
			Data="${Data%"${Data##*[! ]}"}"
			[ -n "$Data" ] && printf '%s' "$Data"
			return $?
		fi

		Off=$((Off + Hdr + FSize))
	done

	return 1
}

# ---------------------------------------------------------------------------
# Friendly getters - v2 frames, then v1 fields, then exiftool when loaded
# ---------------------------------------------------------------------------

# One audio tag by friendly name: title artist album year genre track.
# Id3_Field <file> <field>
Id3_Field() {
	local File=$1 Field=${2,,} Frames F Data

	case "$Field" in
	title) Frames='TIT2 TT2' ;;
	artist) Frames='TPE1 TP1' ;;
	album) Frames='TALB TAL' ;;
	year) Frames='TDRC TYER TYE' ;;
	genre) Frames='TCON TCO' ;;
	track) Frames='TRCK TRK' ;;
	*)
		return 2
		;;
	esac

	for F in $Frames; do
		Data=$(Id3v2_Field "$File" "$F") && [ -n "$Data" ] && break
	done

	# ID3v1 fallback (also fixes v2.2 files when the frame walk failed)
	if [ -z "$Data" ]; then
		Data=$(Id3v1_Field "$File" "$Field")
	fi

	# Genre: "(17)" or plain "17" -> genre name
	if [ "$Field" = 'genre' ] && [ -n "$Data" ]; then
		if [[ "$Data" == \(*\) ]]; then
			Data="${Data#*(}"
			Data="${Data%%)*}"
		fi
		if [[ "$Data" =~ ^[0-9]+$ ]]; then
			Id3v1_Genre_Name "$Data" && return 0
		fi
	fi

	[ -n "$Data" ] && printf '%s' "$Data"
}

# Get_Audio_Title <file>
Get_Audio_Title() {
	local T

	T=$(Id3_Field "$1" title) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Title'
}

# Get_Audio_Artist <file>
Get_Audio_Artist() {
	local T

	T=$(Id3_Field "$1" artist) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Artist'
}

# Get_Audio_Album <file>
Get_Audio_Album() {
	local T

	T=$(Id3_Field "$1" album) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Album'
}

# Get_Audio_Year <file>
Get_Audio_Year() {
	local T

	T=$(Id3_Field "$1" year) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Year'
}

# Get_Audio_Genre <file>
Get_Audio_Genre() {
	local T

	T=$(Id3_Field "$1" genre) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Genre'
}

# Get_Audio_Track <file>
Get_Audio_Track() {
	local T

	T=$(Id3_Field "$1" track) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Track'
}

# Composite directory for audio files: "<Artist>/<Year - Album>", empty
# levels skipped; components sanitized when Sanitize_Name is loaded.
# Get_Audio_Tags_Dir <file>
Get_Audio_Tags_Dir() {
	local File=$1 A Y Al Sub Out

	A=$(Get_Audio_Artist "$File" 2>/dev/null)
	Y=$(Get_Audio_Year "$File" 2>/dev/null)
	Al=$(Get_Audio_Album "$File" 2>/dev/null)

	if [ -n "$Y" ] && [ -n "$Al" ]; then
		Sub="$Y - $Al"
	else
		Sub="${Y}${Al}"
	fi

	Out="$A"
	[ -n "$Sub" ] && Out="${Out:+$Out/}$Sub"

	if [ -n "$Out" ] && declare -F Sanitize_Name >/dev/null 2>&1; then
		local -a Parts
		local P Result=''
		IFS='/' read -ra Parts <<<"$Out"
		for P in "${Parts[@]}"; do
			P=$(Sanitize_Name "$P")
			[ -n "$P" ] && Result="${Result:+$Result/}$P"
		done
		Out=$Result
	fi

	[ -n "$Out" ] && printf '%s' "$Out"
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

declare -A Sort_Stat_Cache=() # <file> = "<birth>|<mtime>" (one stat per file)
declare -A Sort_Date_Cache=() # "<file>|<format>" = formatted date (one date fork per pair)

Files=()   # raw arguments that are files/directories
Targets=() # every single file to treat, collected up front

# ---------------------------------------------------------------------------
# Usage - the short reminder printed when no arguments are given
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# i18n: --lang=XX - 20 built-in UI languages (default: en)
# ---------------------------------------------------------------------------

Lang='en'
LANG_CODES='en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa'

# T: translate a static English string according to $Lang.
T() {
	[ "$Lang" = "en" ] && { printf '%s' "$1"; return; }
	case "$Lang" in
		zh)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' 缺失且其包名未知' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - 自包含的多线程文件整理器' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' '用法: Sort.sh [选项] <文件|目录> ...' ;;
				'Common starts:') printf '%s' '常用启动示例:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' '使用 --help 查看完整选项列表和动态值。' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' '将文件按 MIME 类型、日期、' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' '大小、媒体尺寸、校验和与元数据标题整理到动态目录树中。' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' '重要: remove/delete/trash/shred 作用于计算出的目标(TARGET)' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' '路径,而非源文件。源 = 目标会被拒绝。使用破坏性模式前请' ;;
				'preview output before using a destructive mode.') printf '%s' '先查看预览输出。' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs、--subdirs、--rename 和' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '--extension 的关键字不区分大小写。未知单词将作为字面名称。列表' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '用 + 或 , 连接(例如 --dirs=year+month --subdirs=format,size)。' ;;
				'Date and file times:') printf '%s' '日期和文件时间:' ;;
				'File identity:') printf '%s' '文件标识:' ;;
				'Size and media dimensions:') printf '%s' '大小和媒体尺寸:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' '分辨率层级按较大尺寸判定:' ;;
				'Metadata (needs exiftool):') printf '%s' '元数据(需要 exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' '缺失的工具会在首次使用时提议安装(init-system)。' ;;
				'Modes') printf '%s' '模式' ;;
				'Filtering and processing') printf '%s' '过滤和处理' ;;
				'Destination and naming') printf '%s' '目标和命名' ;;
				'EXIF / metadata') printf '%s' 'EXIF / 元数据' ;;
				'Archives') printf '%s' '压缩包' ;;
				'Output and safety') printf '%s' '输出和安全' ;;
				'Dynamic values') printf '%s' '动态值' ;;
				'Examples') printf '%s' '示例' ;;
				'Summary') printf '%s' '摘要' ;;
				'Unsupported mode: %s') printf '%s' '不支持的模式: %s' ;;
				'Invalid --pause value: %s') printf '%s' '无效的 --pause 值: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred 需要 shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' '无法创建目标目录: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' '未知选项: %s (已忽略)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' '不支持的语言: %s (见 --lang)' ;;
				'Not a file or directory: %s') printf '%s' '不是文件或目录: %s' ;;
				'Files to treat: %s') printf '%s' '待处理文件: %s' ;;
				'Decompression too deep: %s') printf '%s' '解压层级过深: %s' ;;
				'Archive test failed: %s') printf '%s' '压缩包测试失败: %s' ;;
				'Extract failed: %s') printf '%s' '解压失败: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> 删除压缩包' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' '回收站功能需要 trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' '已解压(%s) + 已移入回收站: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' '已解压(%s) + 已粉碎: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' '已解压(%s) + 已删除: %s' ;;
				'Trash failed: %s') printf '%s' '移入回收站失败: %s' ;;
				'Shred failed: %s') printf '%s' '粉碎失败: %s' ;;
				'Delete failed: %s') printf '%s' '删除失败: %s' ;;
				'Not a regular file: %s') printf '%s' '不是普通文件: %s' ;;
				'No MIME type for: %s') printf '%s' '无 MIME 类型: %s' ;;
				'Type skip (%s): %s') printf '%s' '类型跳过 (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' '无法为以下文件生成名称: %s' ;;
				'Cannot create: %s') printf '%s' '无法创建: %s' ;;
				'Same place: %s') printf '%s' '位置相同: %s' ;;
				'Copy failed: %s') printf '%s' '复制失败: %s' ;;
				'Move failed: %s') printf '%s' '移动失败: %s' ;;
				'Remove: target not found: %s') printf '%s' '删除: 未找到目标: %s' ;;
				'Removed: %s') printf '%s' '已删除: %s' ;;
				'Remove failed: %s') printf '%s' '删除失败: %s' ;;
				'Trash: target not found: %s') printf '%s' '回收站: 未找到目标: %s' ;;
				'Trashed: %s') printf '%s' '已移入回收站: %s' ;;
				'Shred: target not found: %s') printf '%s' '粉碎: 未找到目标: %s' ;;
				'Shredded: %s') printf '%s' '已粉碎: %s' ;;
				'Stripped metadata: %s') printf '%s' '已清除元数据: %s' ;;
				'Could not strip metadata: %s') printf '%s' '无法清除元数据: %s' ;;
				'Copied : %s') printf '%s' '已复制 : %s' ;;
				'Moved  : %s') printf '%s' '已移动  : %s' ;;
				'Removed: %s') printf '%s' '已删除: %s' ;;
				'Extracted: %s') printf '%s' '已解压: %s' ;;
				'Preview: %s') printf '%s' '预览: %s' ;;
				'Skipped: %s') printf '%s' '已跳过: %s' ;;
				'Failed : %s') printf '%s' '失败   : %s' ;;
				'Nothing to treat.') printf '%s' '没有可处理的文件。' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '正在整理 %s 个文件 - 模式: %s, 线程: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' '等待后台任务完成...' ;;
				'Finished.') printf '%s' '完成。' ;;
				'Terminated by user!') printf '%s' '被用户终止!' ;;
				'deps: missing: %s') printf '%s' 'deps: 缺失: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: 建议安装: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: 现在安装吗? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: 未安装(设置 DEPS_YES=1 可免确认安装)' ;;
				'deps: skipped') printf '%s' 'deps: 已跳过' ;;
				'deps: no supported package manager found') printf '%s' 'deps: 未找到受支持的软件包管理器' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: 无法获取 root 权限(请以 root 运行或安装 sudo)' ;;
				'Error: ') printf '%s' '错误: ' ;;
				'Warning: ') printf '%s' '警告: ' ;;
				'unknown camera') printf '%s' '未知相机' ;;
				'unknown date') printf '%s' '未知日期' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          界面语言 (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             显示语言列表' ;;
				'Languages') printf '%s' '语言' ;;
				'Available languages (--lang=XX):') printf '%s' '可用语言 (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(默认)            仅预览 - 打印源 <=> 目标' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             将每个文件复制到其排序后的位置' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             将每个文件移动到其排序后的位置' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           删除计算出的目标(TARGET)路径上的文件' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove 的别名' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            将计算出的目标移入桌面回收站' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            对计算出的目标运行 shred -u -n 1' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       上述任意模式的长格式 (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       仅处理 MIME 类型包含 VALUE 的文件' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image、video、audio、pdf、application 等)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        递归遍历所给目录的全部深度' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           包含隐藏文件和目录' ;;
				'--links            Include symbolic links') printf '%s' '--links            包含符号链接' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    每个文件处理后等待' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           线程池大小(默认: nproc,最小 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       排序树的基础目录(默认: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        一级目录组件(默认: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     一级目录之下的目录组件' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     生成文件名(不含扩展名)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  生成扩展名 (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            文件名来自内嵌元数据(PDF /Title、' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   图像 EXIF 日期、音频/视频标签)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          覆盖已存在的目标,否则使用唯一的 ~(N) 名称' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             为图像添加 <相机>/<YYYY-MM-DD> 层级' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            复制/移动后清除目标中的 EXIF/GPS 元数据' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       先解压压缩包到临时目录,再整理其中的内容' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (成功后压缩包本身会被删除;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred 会将该处置方式用于压缩包)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressed名称 = 压缩包内的主目录/单个文件' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          强制彩色输出(在 tty 上自动检测)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored 的别名' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            关闭每个文件的详细信息;仅显示摘要' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          显示每个文件的详细信息(默认)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            打印摘要(默认)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         将每个操作追加一行记录到 FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      写入撤销脚本(默认: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            简短提示' ;;
				'--help             This help') printf '%s' '--help             本帮助' ;;
				'--version          Print the version') printf '%s' '--version          打印版本' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		hi)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' अनुपस्थित है और उसका पैकेज नाम अज्ञात है' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - स्वतंत्र मल्टी-थ्रेडेड फ़ाइल व्यवस्थापक' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'उपयोग: Sort.sh [विकल्प] <फ़ाइल|निर्देशिका> ...' ;;
				'Common starts:') printf '%s' 'सामान्य शुरुआत:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'पूर्ण विकल्प सूची और डायनामिक मानों के लिए --help देखें।' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'फ़ाइलों को MIME, तारीखों, आकारों, मीडिया विमाओं,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'चेकसम और मेटाडेटा शीर्षकों से बने डायनामिक निर्देशिका वृक्ष में व्यवस्थित करता है।' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'महत्वपूर्ण: remove/delete/trash/shred गणना किए गए TARGET' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'पथ पर काम करते हैं, स्रोत पर नहीं। स्रोत = लक्ष्य अस्वीकृत है। किसी विनाशकारी' ;;
				'preview output before using a destructive mode.') printf '%s' 'मोड का उपयोग करने से पहले पूर्वावलोकन आउटपुट जाँचें।' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs, --subdirs, --rename और --extension के लिए' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'कीवर्ड केस-असंवेदनशील हैं। अज्ञात शब्द शाब्दिक नाम बन जाते हैं। सूचियाँ' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '+ या , से जुड़ती हैं (जैसे --dirs=year+month --subdirs=format,size)।' ;;
				'Date and file times:') printf '%s' 'तारीख और फ़ाइल समय:' ;;
				'File identity:') printf '%s' 'फ़ाइल पहचान:' ;;
				'Size and media dimensions:') printf '%s' 'आकार और मीडिया विमाएँ:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'रिज़ॉल्यूशन स्तर बड़े विम से तय होता है:' ;;
				'Metadata (needs exiftool):') printf '%s' 'मेटाडेटा (exiftool आवश्यक):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'अनुपस्थित टूल पहली बार उपयोग पर इंस्टॉल के लिए प्रस्तावित होते हैं (init-system)।' ;;
				'Modes') printf '%s' 'मोड' ;;
				'Filtering and processing') printf '%s' 'फ़िल्टरिंग और प्रोसेसिंग' ;;
				'Destination and naming') printf '%s' 'गंतव्य और नामकरण' ;;
				'EXIF / metadata') printf '%s' 'EXIF / मेटाडेटा' ;;
				'Archives') printf '%s' 'संग्रह' ;;
				'Output and safety') printf '%s' 'आउटपुट और सुरक्षा' ;;
				'Dynamic values') printf '%s' 'डायनामिक मान' ;;
				'Examples') printf '%s' 'उदाहरण' ;;
				'Summary') printf '%s' 'सारांश' ;;
				'Unsupported mode: %s') printf '%s' 'असमर्थित मोड: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'अमान्य --pause मान: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred के लिए shred (coreutils) आवश्यक है' ;;
				'Cannot create target directory: %s') printf '%s' 'लक्ष्य निर्देशिका नहीं बनाई जा सकी: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'अज्ञात विकल्प: %s (नज़रअंदाज़ किया)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'असमर्थित भाषा: %s (--lang देखें)' ;;
				'Not a file or directory: %s') printf '%s' 'फ़ाइल या निर्देशिका नहीं: %s' ;;
				'Files to treat: %s') printf '%s' 'संभाली जाने वाली फ़ाइलें: %s' ;;
				'Decompression too deep: %s') printf '%s' 'डीकंप्रेशन बहुत गहरा: %s' ;;
				'Archive test failed: %s') printf '%s' 'संग्रह परीक्षण विफल: %s' ;;
				'Extract failed: %s') printf '%s' 'निकासना विफल: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> संग्रह हटाएँ' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'ट्रैश के लिए trash-put (trash-cli) आवश्यक है' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'निकाला(%s) + ट्रैश किया: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'निकाला(%s) + श्रेड किया: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'निकाला(%s) + हटाया: %s' ;;
				'Trash failed: %s') printf '%s' 'ट्रैश विफल: %s' ;;
				'Shred failed: %s') printf '%s' 'श्रेड विफल: %s' ;;
				'Delete failed: %s') printf '%s' 'हटाना विफल: %s' ;;
				'Not a regular file: %s') printf '%s' 'सामान्य फ़ाइल नहीं: %s' ;;
				'No MIME type for: %s') printf '%s' 'कोई MIME प्रकार नहीं: %s' ;;
				'Type skip (%s): %s') printf '%s' 'प्रकार छोड़ा (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'नाम नहीं बना सकते: %s' ;;
				'Cannot create: %s') printf '%s' 'नहीं बना सकते: %s' ;;
				'Same place: %s') printf '%s' 'वही स्थान: %s' ;;
				'Copy failed: %s') printf '%s' 'कॉपी विफल: %s' ;;
				'Move failed: %s') printf '%s' 'मूव विफल: %s' ;;
				'Remove: target not found: %s') printf '%s' 'हटाना: लक्ष्य नहीं मिला: %s' ;;
				'Removed: %s') printf '%s' 'हटाया गया: %s' ;;
				'Remove failed: %s') printf '%s' 'हटाना विफल: %s' ;;
				'Trash: target not found: %s') printf '%s' 'ट्रैश: लक्ष्य नहीं मिला: %s' ;;
				'Trashed: %s') printf '%s' 'ट्रैश किया: %s' ;;
				'Shred: target not found: %s') printf '%s' 'श्रेड: लक्ष्य नहीं मिला: %s' ;;
				'Shredded: %s') printf '%s' 'श्रेड किया: %s' ;;
				'Stripped metadata: %s') printf '%s' 'मेटाडेटा हटाया: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'मेटाडेटा नहीं हटा सके: %s' ;;
				'Copied : %s') printf '%s' 'कॉपी : %s' ;;
				'Moved  : %s') printf '%s' 'मूव  : %s' ;;
				'Removed: %s') printf '%s' 'हटाए: %s' ;;
				'Extracted: %s') printf '%s' 'निकाले: %s' ;;
				'Preview: %s') printf '%s' 'पूर्वावलोकन: %s' ;;
				'Skipped: %s') printf '%s' 'छोड़े: %s' ;;
				'Failed : %s') printf '%s' 'विफल : %s' ;;
				'Nothing to treat.') printf '%s' 'संभालने के लिए कुछ नहीं।' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '%s फ़ाइल(ें) क्रमबद्ध हो रही हैं - मोड: %s, थ्रेड: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'पृष्ठभूमि कार्यों का इंतज़ार...' ;;
				'Finished.') printf '%s' 'समाप्त।' ;;
				'Terminated by user!') printf '%s' 'उपयोगकर्ता द्वारा रोका गया!' ;;
				'deps: missing: %s') printf '%s' 'deps: अनुपस्थित: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: इंस्टॉल प्रस्ताव: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: अभी इंस्टॉल करें? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: इंस्टॉल नहीं हुआ (बिना पूछे इंस्टॉल के लिए DEPS_YES=1 सेट करें)' ;;
				'deps: skipped') printf '%s' 'deps: छोड़ा गया' ;;
				'deps: no supported package manager found') printf '%s' 'deps: कोई समर्थित पैकेज मैनेजर नहीं मिला' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: root प्राप्त करने का कोई तरीका नहीं (root के रूप में चलाएँ या sudo इंस्टॉल करें)' ;;
				'Error: ') printf '%s' 'त्रुटि: ' ;;
				'Warning: ') printf '%s' 'चेतावनी: ' ;;
				'unknown camera') printf '%s' 'अज्ञात कैमरा' ;;
				'unknown date') printf '%s' 'अज्ञात तारीख' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          UI भाषा (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             भाषा सूची दिखाएँ' ;;
				'Languages') printf '%s' 'भाषाएँ' ;;
				'Available languages (--lang=XX):') printf '%s' 'उपलब्ध भाषाएँ (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(डिफ़ॉल्ट)         केवल पूर्वावलोकन - स्रोत <=> लक्ष्य प्रिंट करें' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             हर फ़ाइल को उसके क्रमबद्ध स्थान पर कॉपी करें' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             हर फ़ाइल को उसके क्रमबद्ध स्थान पर ले जाएँ' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           गणना किए गए TARGET पथ की फ़ाइल हटाएँ' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove का उपनाम' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            गणना किए गए लक्ष्य को डेस्कटॉप ट्रैश में भेजें' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            गणना किए गए लक्ष्य पर shred -u -n 1 चलाएँ' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       ऊपर के किसी भी मोड का लंबा रूप (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       केवल वे फ़ाइलें जिनके MIME प्रकार में VALUE है' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        दी गई निर्देशिकाओं को पूरी गहराई तक चलें' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           छिपी फ़ाइलें और निर्देशिकाएँ शामिल करें' ;;
				'--links            Include symbolic links') printf '%s' '--links            प्रतीकात्मक लिंक शामिल करें' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    हर फ़ाइल के बाद प्रतीक्षा करें' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           थ्रेड पूल आकार (डिफ़ॉल्ट: nproc, न्यूनतम 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       क्रमबद्ध वृक्ष की आधार निर्देशिका (डिफ़ॉल्ट: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        प्राथमिक निर्देशिका घटक (डिफ़ॉल्ट: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     प्राथमिक के नीचे के निर्देशिका घटक' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     फ़ाइलनाम बनाएँ (बिना एक्सटेंशन)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  एक्सटेंशन बनाएँ (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            फ़ाइलनाम अंतर्निहित मेटाडेटा से (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   छवि EXIF तारीख, ऑडियो/वीडियो टैग)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          मौजूदा लक्ष्यों पर लिखें, अन्यथा अद्वितीय ~(N) नाम' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             छवियों के लिए <कैमरा>/<YYYY-MM-DD> स्तर जोड़ें' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            कॉपी/मूव के बाद लक्ष्यों से EXIF/GPS मेटाडेटा हटाएँ' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       संग्रहों को अस्थायी निर्देशिका में निकालें और सामग्री क्रमबद्ध करें' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (सफलता पर संग्रह स्वयं हटा दिया जाता है;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred वही नियति संग्रह पर लागू करते हैं)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedनाम = संग्रह के अंदर मुख्य निर्देशिका / एकल फ़ाइल' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          रंगीन आउटपुट बाध्य करें (tty पर स्वतः पहचाना गया)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored का उपनाम' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            प्रति-फ़ाइल विवरण बंद; केवल सारांश' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          प्रति-फ़ाइल विवरण चालू (डिफ़ॉल्ट)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            सारांश प्रिंट करें (डिफ़ॉल्ट)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         हर क्रिया की एक पंक्ति FILE में जोड़ें' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      पूर्ववत स्क्रिप्ट लिखें (डिफ़ॉल्ट: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            संक्षिप्त अनुस्मारक' ;;
				'--help             This help') printf '%s' '--help             यह सहायता' ;;
				'--version          Print the version') printf '%s' '--version          संस्करण प्रिंट करें' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		es)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' falta y su nombre de paquete es desconocido' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - organizador con hilos, autónomo' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Uso: Sort.sh [opciones] <archivo|directorio> ...' ;;
				'Common starts:') printf '%s' 'Inicios comunes:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Use --help para la lista completa de opciones y valores dinámicos.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Clasifica archivos en un árbol de directorios dinámico construido a partir' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'de MIME, fechas, tamaños, dimensiones de medios, sumas y títulos.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'IMPORTANTE: remove/delete/trash/shred actúan sobre la ruta TARGET' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'calculada, no sobre el origen. Origen = destino se rechaza. Revise' ;;
				'preview output before using a destructive mode.') printf '%s' 'la vista previa antes de usar un modo destructivo.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Palabras clave insensibles a mayúsculas para --dirs, --subdirs, --rename' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'y --extension. Las palabras desconocidas se vuelven nombres literales.' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'Las listas se unen con + o , (p. ej. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Fechas y tiempos del archivo:' ;;
				'File identity:') printf '%s' 'Identidad del archivo:' ;;
				'Size and media dimensions:') printf '%s' 'Tamaño y dimensiones de medios:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Los niveles de resolución usan la dimensión mayor:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadatos (requiere exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Las herramientas faltantes se proponen para instalar en el primer uso (init-system).' ;;
				'Modes') printf '%s' 'Modos' ;;
				'Filtering and processing') printf '%s' 'Filtrado y procesamiento' ;;
				'Destination and naming') printf '%s' 'Destino y nombres' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadatos' ;;
				'Archives') printf '%s' 'Archivos comprimidos' ;;
				'Output and safety') printf '%s' 'Salida y seguridad' ;;
				'Dynamic values') printf '%s' 'Valores dinámicos' ;;
				'Examples') printf '%s' 'Ejemplos' ;;
				'Summary') printf '%s' 'Resumen' ;;
				'Unsupported mode: %s') printf '%s' 'Modo no admitido: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Valor de --pause no válido: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred requiere shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'No se puede crear el directorio destino: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Opción desconocida: %s (ignorada)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Idioma no admitido: %s (vea --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'No es archivo ni directorio: %s' ;;
				'Files to treat: %s') printf '%s' 'Archivos a tratar: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Descompresión demasiado profunda: %s' ;;
				'Archive test failed: %s') printf '%s' 'Prueba del archivo fallida: %s' ;;
				'Extract failed: %s') printf '%s' 'Extracción fallida: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> borrar el archivo' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'La papelera necesita trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Extraído(%s) + a la papelera: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Extraído(%s) + destruido: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Extraído(%s) + borrado: %s' ;;
				'Trash failed: %s') printf '%s' 'Papelera fallida: %s' ;;
				'Shred failed: %s') printf '%s' 'Destrucción fallida: %s' ;;
				'Delete failed: %s') printf '%s' 'Borrado fallido: %s' ;;
				'Not a regular file: %s') printf '%s' 'No es un archivo regular: %s' ;;
				'No MIME type for: %s') printf '%s' 'Sin tipo MIME para: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Tipo omitido (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'No se puede construir un nombre para: %s' ;;
				'Cannot create: %s') printf '%s' 'No se puede crear: %s' ;;
				'Same place: %s') printf '%s' 'Mismo lugar: %s' ;;
				'Copy failed: %s') printf '%s' 'Copia fallida: %s' ;;
				'Move failed: %s') printf '%s' 'Movimiento fallido: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: destino no encontrado: %s' ;;
				'Removed: %s') printf '%s' 'Eliminado: %s' ;;
				'Remove failed: %s') printf '%s' 'Eliminación fallida: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: destino no encontrado: %s' ;;
				'Trashed: %s') printf '%s' 'A la papelera: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: destino no encontrado: %s' ;;
				'Shredded: %s') printf '%s' 'Destruido: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadatos eliminados: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'No se pudieron eliminar los metadatos: %s' ;;
				'Copied : %s') printf '%s' 'Copiados : %s' ;;
				'Moved  : %s') printf '%s' 'Movidos  : %s' ;;
				'Removed: %s') printf '%s' 'Eliminados: %s' ;;
				'Extracted: %s') printf '%s' 'Extraídos: %s' ;;
				'Preview: %s') printf '%s' 'Vista previa: %s' ;;
				'Skipped: %s') printf '%s' 'Omitidos: %s' ;;
				'Failed : %s') printf '%s' 'Fallidos : %s' ;;
				'Nothing to treat.') printf '%s' 'Nada que tratar.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Clasificando %s archivo(s) - modo: %s, hilos: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Esperando a que terminen los trabajos en segundo plano...' ;;
				'Finished.') printf '%s' 'Terminado.' ;;
				'Terminated by user!') printf '%s' '¡Interrumpido por el usuario!' ;;
				'deps: missing: %s') printf '%s' 'deps: faltan: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: instalación propuesta: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: ¿instalar ahora? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: no instalado (fije DEPS_YES=1 para instalar sin preguntar)' ;;
				'deps: skipped') printf '%s' 'deps: omitido' ;;
				'deps: no supported package manager found') printf '%s' 'deps: no se encontró un gestor de paquetes admitido' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: sin forma de obtener root (ejecute como root o instale sudo)' ;;
				'Error: ') printf '%s' 'Error: ' ;;
				'Warning: ') printf '%s' 'Advertencia: ' ;;
				'unknown camera') printf '%s' 'cámara desconocida' ;;
				'unknown date') printf '%s' 'fecha desconocida' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Idioma de la interfaz (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Muestra la lista de idiomas' ;;
				'Languages') printf '%s' 'Idiomas' ;;
				'Available languages (--lang=XX):') printf '%s' 'Idiomas disponibles (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(predeterminado)   Solo vista previa - imprime origen <=> destino' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Copia cada archivo a su ubicación clasificada' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Mueve cada archivo a su ubicación clasificada' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Elimina el archivo en la ruta TARGET calculada' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias de --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Envía el destino calculado a la papelera del escritorio' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Ejecuta shred -u -n 1 sobre el destino calculado' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Forma larga de cualquier modo de arriba (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Solo archivos cuyo tipo MIME contenga VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Recorre los directorios dados a profundidad completa' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Incluye archivos y directorios ocultos' ;;
				'--links            Include symbolic links') printf '%s' '--links            Incluye enlaces simbólicos' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Espera tras cada archivo' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Tamaño del grupo de hilos (predeterminado: nproc, mín 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Directorio base del árbol clasificado (predeterminado: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Componentes de directorio primarios (predeterminado: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Componentes de directorio bajo el primario' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Genera el nombre de archivo (sin extensión)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Genera la extensión (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Nombre desde metadatos incrustados (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   fecha EXIF de imagen, etiquetas de audio/vídeo)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Sobrescribe destinos existentes, si no nombre único ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Añade niveles <Cámara>/<YYYY-MM-DD> para imágenes' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Elimina metadatos EXIF/GPS de los destinos tras copiar/mover' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Extrae archivos comprimidos a un dir temporal y clasifica el contenido' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (el propio archivo se borra tras el éxito;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred aplican ese destino al comprimido)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNombre = dir principal / archivo único dentro del comprimido' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Fuerza salida con color (autodetectado en una tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias de --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Detalles por archivo desactivados; solo resumen' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Detalles por archivo activados (predeterminado)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Imprime el resumen (predeterminado)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Añade una línea por acción a FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Escribe un script de deshacer (predeterminado: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Recordatorio breve' ;;
				'--help             This help') printf '%s' '--help             Esta ayuda' ;;
				'--version          Print the version') printf '%s' '--version          Imprime la versión' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		fr)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps : '\''%s'\'' est absent et son nom de paquet est inconnu' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - organisateur multithread autonome' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Utilisation : Sort.sh [options] <fichier|répertoire> ...' ;;
				'Common starts:') printf '%s' 'Démarrages courants :' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Utilisez --help pour la liste complète des options et des valeurs dynamiques.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Classe les fichiers dans une arborescence dynamique construite à partir' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'du MIME, des dates, tailles, dimensions média, sommes et titres.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'IMPORTANT : remove/delete/trash/shred agissent sur le chemin TARGET' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'calculé, pas sur la source. Source = cible est refusé. Vérifiez' ;;
				'preview output before using a destructive mode.') printf '%s' 'la prévisualisation avant d’utiliser un mode destructif.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Mots-clés insensibles à la casse pour --dirs, --subdirs, --rename et' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '--extension. Les mots inconnus deviennent des noms littéraux. Les listes' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'sont jointes par + ou , (ex. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Dates et temps du fichier :' ;;
				'File identity:') printf '%s' 'Identité du fichier :' ;;
				'Size and media dimensions:') printf '%s' 'Taille et dimensions média :' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Les paliers de résolution utilisent la plus grande dimension :' ;;
				'Metadata (needs exiftool):') printf '%s' 'Métadonnées (nécessite exiftool) :' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Les outils manquants sont proposés à l’installation au premier usage (init-system).' ;;
				'Modes') printf '%s' 'Modes' ;;
				'Filtering and processing') printf '%s' 'Filtrage et traitement' ;;
				'Destination and naming') printf '%s' 'Destination et nommage' ;;
				'EXIF / metadata') printf '%s' 'EXIF / métadonnées' ;;
				'Archives') printf '%s' 'Archives' ;;
				'Output and safety') printf '%s' 'Sortie et sécurité' ;;
				'Dynamic values') printf '%s' 'Valeurs dynamiques' ;;
				'Examples') printf '%s' 'Exemples' ;;
				'Summary') printf '%s' 'Résumé' ;;
				'Unsupported mode: %s') printf '%s' 'Mode non pris en charge : %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Valeur --pause invalide : %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred requiert shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Impossible de créer le répertoire cible : %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Option inconnue : %s (ignorée)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Langue non prise en charge : %s (voir --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Ni fichier ni répertoire : %s' ;;
				'Files to treat: %s') printf '%s' 'Fichiers à traiter : %s' ;;
				'Decompression too deep: %s') printf '%s' 'Décompression trop profonde : %s' ;;
				'Archive test failed: %s') printf '%s' 'Test de l’archive échoué : %s' ;;
				'Extract failed: %s') printf '%s' 'Extraction échouée : %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s) : %s <=> supprimer l’archive' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'La corbeille requiert trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Extrait(%s) + mis à la corbeille : %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Extrait(%s) + broyé : %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Extrait(%s) + supprimé : %s' ;;
				'Trash failed: %s') printf '%s' 'Échec de la corbeille : %s' ;;
				'Shred failed: %s') printf '%s' 'Échec du broyage : %s' ;;
				'Delete failed: %s') printf '%s' 'Échec de la suppression : %s' ;;
				'Not a regular file: %s') printf '%s' 'Pas un fichier régulier : %s' ;;
				'No MIME type for: %s') printf '%s' 'Aucun type MIME pour : %s' ;;
				'Type skip (%s): %s') printf '%s' 'Type ignoré (%s) : %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF : %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Impossible de construire un nom pour : %s' ;;
				'Cannot create: %s') printf '%s' 'Impossible de créer : %s' ;;
				'Same place: %s') printf '%s' 'Même emplacement : %s' ;;
				'Copy failed: %s') printf '%s' 'Échec de la copie : %s' ;;
				'Move failed: %s') printf '%s' 'Échec du déplacement : %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove : cible introuvable : %s' ;;
				'Removed: %s') printf '%s' 'Supprimé : %s' ;;
				'Remove failed: %s') printf '%s' 'Échec de la suppression : %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash : cible introuvable : %s' ;;
				'Trashed: %s') printf '%s' 'Mis à la corbeille : %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred : cible introuvable : %s' ;;
				'Shredded: %s') printf '%s' 'Broyé : %s' ;;
				'Stripped metadata: %s') printf '%s' 'Métadonnées supprimées : %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Impossible de supprimer les métadonnées : %s' ;;
				'Copied : %s') printf '%s' 'Copiés : %s' ;;
				'Moved  : %s') printf '%s' 'Déplacés : %s' ;;
				'Removed: %s') printf '%s' 'Supprimés : %s' ;;
				'Extracted: %s') printf '%s' 'Extraits : %s' ;;
				'Preview: %s') printf '%s' 'Aperçus : %s' ;;
				'Skipped: %s') printf '%s' 'Ignorés : %s' ;;
				'Failed : %s') printf '%s' 'Échoués : %s' ;;
				'Nothing to treat.') printf '%s' 'Rien à traiter.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Classement de %s fichier(s) - mode : %s, threads : %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'En attente de la fin des tâches de fond...' ;;
				'Finished.') printf '%s' 'Terminé.' ;;
				'Terminated by user!') printf '%s' 'Interrompu par l’utilisateur !' ;;
				'deps: missing: %s') printf '%s' 'deps : manquants : %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps : installation proposée : %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps : installer maintenant ? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps : non installé (fixez DEPS_YES=1 pour installer sans demander)' ;;
				'deps: skipped') printf '%s' 'deps : ignoré' ;;
				'deps: no supported package manager found') printf '%s' 'deps : aucun gestionnaire de paquets pris en charge' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps : aucun moyen d’obtenir root (lancez en root ou installez sudo)' ;;
				'Error: ') printf '%s' 'Erreur : ' ;;
				'Warning: ') printf '%s' 'Avertissement : ' ;;
				'unknown camera') printf '%s' 'appareil inconnu' ;;
				'unknown date') printf '%s' 'date inconnue' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Langue de l’interface (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Affiche la liste des langues' ;;
				'Languages') printf '%s' 'Langues' ;;
				'Available languages (--lang=XX):') printf '%s' 'Langues disponibles (--lang=XX) :' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(défaut)           Aperçu seul - affiche source <=> cible' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Copie chaque fichier vers son emplacement classé' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Déplace chaque fichier vers son emplacement classé' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Supprime le fichier au chemin TARGET calculé' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias de --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Envoie la cible calculée à la corbeille du bureau' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Exécute shred -u -n 1 sur la cible calculée' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Forme longue de tout mode ci-dessus (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Seulement les fichiers dont le type MIME contient VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Parcourt les répertoires fournis sur toute la profondeur' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Inclut les fichiers et répertoires cachés' ;;
				'--links            Include symbolic links') printf '%s' '--links            Inclut les liens symboliques' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Attend après chaque fichier' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Taille du pool de threads (défaut : nproc, min 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Répertoire de base de l’arbre classé (défaut : .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Composants de répertoire primaires (défaut : mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Composants de répertoire sous le primaire' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Génère le nom de fichier (sans extension)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Génère l’extension (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Nom depuis les métadonnées incrustées (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   date EXIF d’image, tags audio/vidéo)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Écrase les cibles existantes, sinon nom unique ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Ajoute des niveaux <Appareil>/<AAAA-MM-JJ> pour les images' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Supprime les métadonnées EXIF/GPS des cibles après copie/déplacement' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Extrait les archives vers un répertoire temporaire et classe le contenu' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (l’archive elle-même est supprimée après succès;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred appliquent ce sort à l’archive)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNom = répertoire principal / fichier unique dans l’archive' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Force la sortie colorée (autodétectée sur un tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias de --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Détails par fichier désactivés ; résumé seul' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Détails par fichier activés (défaut)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Affiche le résumé (défaut)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Ajoute une ligne par action à FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Écrit un script d’annulation (défaut : sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Rappel court' ;;
				'--help             This help') printf '%s' '--help             Cette aide' ;;
				'--version          Print the version') printf '%s' '--version          Affiche la version' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		ar)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' مفقود واسم حزمته غير معروف' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - منظِّم ملفات متعدد الخيوط قائم بذاته' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'الاستخدام: Sort.sh [الخيارات] <ملف|دليل> ...' ;;
				'Common starts:') printf '%s' 'بدايات شائعة:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'استخدم --help لقائمة الخيارات الكاملة والقيم الديناميكية.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'يرتِّب الملفات في شجرة أدلة ديناميكية مبنية من MIME والتواريخ' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'والأحجام وأبعاد الوسائط والمجاميع الاختبارية وعناوين البيانات الوصفية.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'مهم: remove/delete/trash/shred تعمل على مسار الهدف TARGET' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'المحسوب، وليس على المصدر. المصدر = الهدف مرفوض. راجع مخرجات' ;;
				'preview output before using a destructive mode.') printf '%s' 'المعاينة قبل استخدام وضع مدمر.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'الكلمات المفتاحية لـ --dirs و--subdirs و--rename و' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '--extension غير حساسة لحالة الأحرف. الكلمات المجهولة تصبح أسماء حرفية.' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'تُربط القوائم بـ + أو ، (مثال: --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'التواريخ وأوقات الملف:' ;;
				'File identity:') printf '%s' 'هوية الملف:' ;;
				'Size and media dimensions:') printf '%s' 'الحجم وأبعاد الوسائط:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'تُحدَّد فئات الدقة بالبعد الأكبر:' ;;
				'Metadata (needs exiftool):') printf '%s' 'البيانات الوصفية (تحتاج exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'تُقترح الأدوات الناقصة للتثبيت عند أول استخدام (init-system).' ;;
				'Modes') printf '%s' 'الأوضاع' ;;
				'Filtering and processing') printf '%s' 'التصفية والمعالجة' ;;
				'Destination and naming') printf '%s' 'الوجهة والتسمية' ;;
				'EXIF / metadata') printf '%s' 'EXIF / البيانات الوصفية' ;;
				'Archives') printf '%s' 'الأرشيفات' ;;
				'Output and safety') printf '%s' 'المخرجات والسلامة' ;;
				'Dynamic values') printf '%s' 'القيم الديناميكية' ;;
				'Examples') printf '%s' 'أمثلة' ;;
				'Summary') printf '%s' 'الملخص' ;;
				'Unsupported mode: %s') printf '%s' 'وضع غير مدعوم: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'قيمة --pause غير صالحة: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred يتطلب shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'تعذّر إنشاء دليل الوجهة: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'خيار مجهول: %s (تم تجاهله)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'لغة غير مدعومة: %s (انظر --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'ليس ملفًا ولا دليلًا: %s' ;;
				'Files to treat: %s') printf '%s' 'الملفات المطلوب معالجتها: %s' ;;
				'Decompression too deep: %s') printf '%s' 'فك الضغط عميق جدًا: %s' ;;
				'Archive test failed: %s') printf '%s' 'فشل اختبار الأرشيف: %s' ;;
				'Extract failed: %s') printf '%s' 'فشل الاستخراج: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> حذف الأرشيف' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'السلة تحتاج trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'استُخرج(%s) + أُلقي في السلة: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'استُخرج(%s) + مُزِّق: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'استُخرج(%s) + حُذف: %s' ;;
				'Trash failed: %s') printf '%s' 'فشل الإلقاء في السلة: %s' ;;
				'Shred failed: %s') printf '%s' 'فشل التمزيق: %s' ;;
				'Delete failed: %s') printf '%s' 'فشل الحذف: %s' ;;
				'Not a regular file: %s') printf '%s' 'ليس ملفًا عاديًا: %s' ;;
				'No MIME type for: %s') printf '%s' 'لا يوجد نوع MIME لـ: %s' ;;
				'Type skip (%s): %s') printf '%s' 'تخطي النوع (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'تعذّر بناء اسم لـ: %s' ;;
				'Cannot create: %s') printf '%s' 'تعذّر الإنشاء: %s' ;;
				'Same place: %s') printf '%s' 'نفس المكان: %s' ;;
				'Copy failed: %s') printf '%s' 'فشل النسخ: %s' ;;
				'Move failed: %s') printf '%s' 'فشل النقل: %s' ;;
				'Remove: target not found: %s') printf '%s' 'حذف: الهدف غير موجود: %s' ;;
				'Removed: %s') printf '%s' 'حُذف: %s' ;;
				'Remove failed: %s') printf '%s' 'فشل الحذف: %s' ;;
				'Trash: target not found: %s') printf '%s' 'سلة: الهدف غير موجود: %s' ;;
				'Trashed: %s') printf '%s' 'أُلقي في السلة: %s' ;;
				'Shred: target not found: %s') printf '%s' 'تمزيق: الهدف غير موجود: %s' ;;
				'Shredded: %s') printf '%s' 'مُزِّق: %s' ;;
				'Stripped metadata: %s') printf '%s' 'أُزيلت البيانات الوصفية: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'تعذّرت إزالة البيانات الوصفية: %s' ;;
				'Copied : %s') printf '%s' 'منسوخ : %s' ;;
				'Moved  : %s') printf '%s' 'منقول  : %s' ;;
				'Removed: %s') printf '%s' 'محذوف: %s' ;;
				'Extracted: %s') printf '%s' 'مستخرج: %s' ;;
				'Preview: %s') printf '%s' 'معاينة: %s' ;;
				'Skipped: %s') printf '%s' 'متخطى: %s' ;;
				'Failed : %s') printf '%s' 'فاشل : %s' ;;
				'Nothing to treat.') printf '%s' 'لا شيء للمعالجة.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'ترتيب %s ملف - الوضع: %s، الخيوط: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'في انتظار انتهاء المهام الخلفية...' ;;
				'Finished.') printf '%s' 'انتهى.' ;;
				'Terminated by user!') printf '%s' 'أوقفه المستخدم!' ;;
				'deps: missing: %s') printf '%s' 'deps: ناقص: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: تثبيت مقترح: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: التثبيت الآن؟ [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: لم يُثبَّت (اضبط DEPS_YES=1 للتثبيت دون سؤال)' ;;
				'deps: skipped') printf '%s' 'deps: تم التخطي' ;;
				'deps: no supported package manager found') printf '%s' 'deps: لم يُعثر على مدير حزم مدعوم' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: لا طريقة للحصول على root (شغِّل كـ root أو ثبِّت sudo)' ;;
				'Error: ') printf '%s' 'خطأ: ' ;;
				'Warning: ') printf '%s' 'تحذير: ' ;;
				'unknown camera') printf '%s' 'كاميرا مجهولة' ;;
				'unknown date') printf '%s' 'تاريخ مجهول' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          لغة الواجهة (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             اطبع قائمة اللغات' ;;
				'Languages') printf '%s' 'اللغات' ;;
				'Available languages (--lang=XX):') printf '%s' 'اللغات المتاحة (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(افتراضي)          معاينة فقط - يطبع المصدر <=> الهدف' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             ينسخ كل ملف إلى موقعه المرتَّب' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             ينقل كل ملف إلى موقعه المرتَّب' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           يحذف الملف في مسار الهدف TARGET المحسوب' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           بديل لـ --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            يرسل الهدف المحسوب إلى سلة سطح المكتب' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            يشغّل shred -u -n 1 على الهدف المحسوب' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       الصيغة الطويلة لأي وضع أعلاه (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       فقط الملفات التي يحتوي نوع MIME فيها على VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image، video، audio، pdf، application، ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        يجول الأدلة المعطاة بعمق كامل' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           يشمل الملفات والأدلة المخفية' ;;
				'--links            Include symbolic links') printf '%s' '--links            يشمل الروابط الرمزية' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    ينتظر بعد كل ملف' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           حجم مجموعة الخيوط (افتراضي: nproc، أدنى 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       الدليل الأساسي لشجرة الترتيب (افتراضي: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        مكوّنات الدليل الأولية (افتراضي: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     مكوّنات الدليل تحت الأولية' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     يولّد اسم الملف (بدون امتداد)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  يولّد الامتداد (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            الاسم من البيانات الوصفية المدمجة (PDF /Title،' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   تاريخ EXIF للصورة، وسوم الصوت/الفيديو)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          يستبدل الأهداف الموجودة، وإلا اسم فريد ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             يضيف مستويات <الكاميرا>/<YYYY-MM-DD> للصور' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            يزيل بيانات EXIF/GPS الوصفية من الأهداف بعد النسخ/النقل' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       يستخرج الأرشيفات إلى دليل مؤقت ويرتِّب المحتويات' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (يُحذف الأرشيف نفسه بعد النجاح؛' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred تطبقان ذلك المصير على الأرشيف)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedالاسم = الدليل الرئيس / الملف الوحيد داخل الأرشيف' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          يجبر المخرجات الملونة (تُكتشف تلقائيًا على tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           بديل لـ --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            إيقاف تفاصيل كل ملف؛ الملخص فقط' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          تشغيل تفاصيل كل ملف (افتراضي)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            يطبع الملخص (افتراضي)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         يضيف سطرًا لكل عملية إلى FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      يكتب سكربت تراجع (افتراضي: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            تذكير قصير' ;;
				'--help             This help') printf '%s' '--help             هذه المساعدة' ;;
				'--version          Print the version') printf '%s' '--version          يطبع الإصدار' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		bn)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' অনুপস্থিত এবং এর প্যাকেজ নাম অজানা' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - স্বয়ংসম্পূর্ণ মাল্টি-থ্রেডেড ফাইল সংগঠক' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'ব্যবহার: Sort.sh [বিকল্প] <ফাইল|ডিরেক্টরি> ...' ;;
				'Common starts:') printf '%s' 'সাধারণ শুরু:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'সম্পূর্ণ বিকল্প তালিকা ও ডায়নামিক মানের জন্য --help দেখুন।' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'MIME, তারিখ, আকার, মিডিয়া মাত্রা, চেকসাম ও মেটাডেটা শিরোনাম থেকে' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'গঠিত ডায়নামিক ডিরেক্টরি বৃক্ষে ফাইলগুলো সাজায়।' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'গুরুত্বপূর্ণ: remove/delete/trash/shred গণনাকৃত TARGET' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'পথে কাজ করে, উৎসে নয়। উৎস = লক্ষ্য প্রত্যাখ্যাত। ধ্বংসাত্মক মোড' ;;
				'preview output before using a destructive mode.') printf '%s' 'ব্যবহারের আগে প্রিভিউ আউটপুট দেখে নিন।' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs, --subdirs, --rename ও --extension-এর জন্য' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'কীওয়ার্ড কেস-উপেক্ষক। অজানা শব্দ আক্ষরিক নাম হয়ে যায়। তালিকা' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '+ বা , দিয়ে যুক্ত হয় (যেমন --dirs=year+month --subdirs=format,size)।' ;;
				'Date and file times:') printf '%s' 'তারিখ ও ফাইলের সময়:' ;;
				'File identity:') printf '%s' 'ফাইল পরিচয়:' ;;
				'Size and media dimensions:') printf '%s' 'আকার ও মিডিয়া মাত্রা:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'রেজোলিউশন স্তর বড় মাত্রা দিয়ে নির্ধারিত হয়:' ;;
				'Metadata (needs exiftool):') printf '%s' 'মেটাডেটা (exiftool প্রয়োজন):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'অনুপস্থিত টুল প্রথম ব্যবহারে ইনস্টলের প্রস্তাব পায় (init-system)।' ;;
				'Modes') printf '%s' 'মোড' ;;
				'Filtering and processing') printf '%s' 'ফিল্টার ও প্রসেসিং' ;;
				'Destination and naming') printf '%s' 'গন্তব্য ও নামকরণ' ;;
				'EXIF / metadata') printf '%s' 'EXIF / মেটাডেটা' ;;
				'Archives') printf '%s' 'আর্কাইভ' ;;
				'Output and safety') printf '%s' 'আউটপুট ও নিরাপত্তা' ;;
				'Dynamic values') printf '%s' 'ডায়নামিক মান' ;;
				'Examples') printf '%s' 'উদাহরণ' ;;
				'Summary') printf '%s' 'সারসংক্ষেপ' ;;
				'Unsupported mode: %s') printf '%s' 'অসমর্থিত মোড: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'অবৈধ --pause মান: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred-এর জন্য shred (coreutils) প্রয়োজন' ;;
				'Cannot create target directory: %s') printf '%s' 'লক্ষ্য ডিরেক্টরি তৈরি করা যায়নি: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'অজানা বিকল্প: %s (উপেক্ষিত)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'অসমর্থিত ভাষা: %s (--lang দেখুন)' ;;
				'Not a file or directory: %s') printf '%s' 'ফাইল বা ডিরেক্টরি নয়: %s' ;;
				'Files to treat: %s') printf '%s' 'প্রক্রিয়াকরণের ফাইল: %s' ;;
				'Decompression too deep: %s') printf '%s' 'ডিকম্প্রেশন অতিরিক্ত গভীর: %s' ;;
				'Archive test failed: %s') printf '%s' 'আর্কাইভ পরীক্ষা ব্যর্থ: %s' ;;
				'Extract failed: %s') printf '%s' 'নিষ্কাশন ব্যর্থ: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> আর্কাইভ মুছুন' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'ট্র্যাশের জন্য trash-put (trash-cli) প্রয়োজন' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'নিষ্কাশিত(%s) + ট্র্যাশ: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'নিষ্কাশিত(%s) + শ্রেড: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'নিষ্কাশিত(%s) + মুছে ফেলা: %s' ;;
				'Trash failed: %s') printf '%s' 'ট্র্যাশ ব্যর্থ: %s' ;;
				'Shred failed: %s') printf '%s' 'শ্রেড ব্যর্থ: %s' ;;
				'Delete failed: %s') printf '%s' 'মুছে ফেলা ব্যর্থ: %s' ;;
				'Not a regular file: %s') printf '%s' 'সাধারণ ফাইল নয়: %s' ;;
				'No MIME type for: %s') printf '%s' 'MIME ধরন নেই: %s' ;;
				'Type skip (%s): %s') printf '%s' 'ধরন এড়ানো (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'নাম তৈরি করা যায়নি: %s' ;;
				'Cannot create: %s') printf '%s' 'তৈরি করা যায়নি: %s' ;;
				'Same place: %s') printf '%s' 'একই জায়গা: %s' ;;
				'Copy failed: %s') printf '%s' 'কপি ব্যর্থ: %s' ;;
				'Move failed: %s') printf '%s' 'সরানো ব্যর্থ: %s' ;;
				'Remove: target not found: %s') printf '%s' 'মুছুন: লক্ষ্য পাওয়া যায়নি: %s' ;;
				'Removed: %s') printf '%s' 'মুছে ফেলা হয়েছে: %s' ;;
				'Remove failed: %s') printf '%s' 'মুছে ফেলা ব্যর্থ: %s' ;;
				'Trash: target not found: %s') printf '%s' 'ট্র্যাশ: লক্ষ্য পাওয়া যায়নি: %s' ;;
				'Trashed: %s') printf '%s' 'ট্র্যাশ করা হয়েছে: %s' ;;
				'Shred: target not found: %s') printf '%s' 'শ্রেড: লক্ষ্য পাওয়া যায়নি: %s' ;;
				'Shredded: %s') printf '%s' 'শ্রেড করা হয়েছে: %s' ;;
				'Stripped metadata: %s') printf '%s' 'মেটাডেটা সরানো হয়েছে: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'মেটাডেটা সরানো যায়নি: %s' ;;
				'Copied : %s') printf '%s' 'কপি : %s' ;;
				'Moved  : %s') printf '%s' 'সরানো : %s' ;;
				'Removed: %s') printf '%s' 'মুছে ফেলা: %s' ;;
				'Extracted: %s') printf '%s' 'নিষ্কাশিত: %s' ;;
				'Preview: %s') printf '%s' 'প্রিভিউ: %s' ;;
				'Skipped: %s') printf '%s' 'এড়ানো: %s' ;;
				'Failed : %s') printf '%s' 'ব্যর্থ : %s' ;;
				'Nothing to treat.') printf '%s' 'প্রক্রিয়াকরণের কিছু নেই।' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '%s ফাইল সাজানো হচ্ছে - মোড: %s, থ্রেড: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'পটভূমির কাজ শেষ হওয়ার অপেক্ষায়...' ;;
				'Finished.') printf '%s' 'সম্পন্ন।' ;;
				'Terminated by user!') printf '%s' 'ব্যবহারকারী দ্বারা বন্ধ!' ;;
				'deps: missing: %s') printf '%s' 'deps: অনুপস্থিত: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: ইনস্টল প্রস্তাব: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: এখনই ইনস্টল? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: ইনস্টল হয়নি (জিজ্ঞাসা ছাড়া ইনস্টলের জন্য DEPS_YES=1 দিন)' ;;
				'deps: skipped') printf '%s' 'deps: এড়ানো হয়েছে' ;;
				'deps: no supported package manager found') printf '%s' 'deps: কোনো সমর্থিত প্যাকেজ ম্যানেজার পাওয়া যায়নি' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: root পাওয়ার উপায় নেই (root হিসেবে চালান বা sudo ইনস্টল করুন)' ;;
				'Error: ') printf '%s' 'ত্রুটি: ' ;;
				'Warning: ') printf '%s' 'সতর্কতা: ' ;;
				'unknown camera') printf '%s' 'অজানা ক্যামেরা' ;;
				'unknown date') printf '%s' 'অজানা তারিখ' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          UI ভাষা (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             ভাষার তালিকা দেখান' ;;
				'Languages') printf '%s' 'ভাষা' ;;
				'Available languages (--lang=XX):') printf '%s' 'উপলব্ধ ভাষা (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(ডিফল্ট)           শুধু প্রিভিউ - উৎস <=> লক্ষ্য প্রিন্ট করে' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             প্রতিটি ফাইল তার সাজানো স্থানে কপি করে' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             প্রতিটি ফাইল তার সাজানো স্থানে সরায়' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           গণনাকৃত TARGET পথের ফাইল মুছে ফেলে' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove-এর বিকল্প নাম' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            গণনাকৃত লক্ষ্য ডেস্কটপ ট্র্যাশে পাঠায়' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            গণনাকৃত লক্ষ্যে shred -u -n 1 চালায়' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       উপরের যেকোনো মোডের দীর্ঘ রূপ (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       শুধু যেসব ফাইলের MIME ধরনে VALUE আছে' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        দেওয়া ডিরেক্টরিগুলো পূর্ণ গভীরতায় ঘোরে' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           লুকানো ফাইল ও ডিরেক্টরি অন্তর্ভুক্ত করে' ;;
				'--links            Include symbolic links') printf '%s' '--links            সিম্বলিক লিঙ্ক অন্তর্ভুক্ত করে' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    প্রতিটি ফাইলের পরে অপেক্ষা করে' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           থ্রেড পুলের আকার (ডিফল্ট: nproc, সর্বনিম্ন 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       সাজানো বৃক্ষের ভিত্তি ডিরেক্টরি (ডিফল্ট: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        প্রাথমিক ডিরেক্টরি উপাদান (ডিফল্ট: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     প্রাথমিকের নিচের ডিরেক্টরি উপাদান' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     ফাইলের নাম তৈরি করে (এক্সটেনশন ছাড়া)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  এক্সটেনশন তৈরি করে (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            অন্তর্নিহিত মেটাডেটা থেকে নাম (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   ছবির EXIF তারিখ, অডিও/ভিডিও ট্যাগ)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          বিদ্যমান লক্ষ্য মুছে লেখে, নইলে অনন্য ~(N) নাম' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             ছবির জন্য <ক্যামেরা>/<YYYY-MM-DD> স্তর যোগ করে' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            কপি/সরানোর পরে লক্ষ্য থেকে EXIF/GPS মেটাডেটা সরায়' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       আর্কাইভ সাময়িক ডিরেক্টরিতে নিষ্কাশন করে বিষয়বস্তু সাজায়' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (সফল হলে আর্কাইভ নিজেই মুছে যায়;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred সেই নিয়তি আর্কাইভে প্রয়োগ করে)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedনাম = আর্কাইভের ভেতরের মূল ডিরেক্টরি / একক ফাইল' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          রঙিন আউটপুট বাধ্য করে (tty-তে স্বয়ংক্রিয় শনাক্ত)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored-এর বিকল্প নাম' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            প্রতি-ফাইল বিবরণ বন্ধ; শুধু সারসংক্ষেপ' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          প্রতি-ফাইল বিবরণ চালু (ডিফল্ট)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            সারসংক্ষেপ প্রিন্ট করে (ডিফল্ট)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         প্রতিটি কাজের এক লাইন FILE-এ যোগ করে' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      আনডু স্ক্রিপ্ট লেখে (ডিফল্ট: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            সংক্ষিপ্ত স্মারক' ;;
				'--help             This help') printf '%s' '--help             এই সাহায্য' ;;
				'--version          Print the version') printf '%s' '--version          সংস্করণ প্রিন্ট করে' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		pt)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' está ausente e seu nome de pacote é desconhecido' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - organizador com threads, autônomo' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Uso: Sort.sh [opções] <arquivo|diretório> ...' ;;
				'Common starts:') printf '%s' 'Inícios comuns:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Use --help para a lista completa de opções e valores dinâmicos.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Classifica arquivos numa árvore de diretórios dinâmica construída a partir' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'de MIME, datas, tamanhos, dimensões de mídia, somas de verificação e títulos.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'IMPORTANTE: remove/delete/trash/shred atuam no caminho TARGET' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'calculado, não na origem. Origem = destino é recusado. Revise a' ;;
				'preview output before using a destructive mode.') printf '%s' 'pré-visualização antes de usar um modo destrutivo.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Palavras-chave sem distinção de maiúsculas para --dirs, --subdirs,' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '--rename e --extension. Palavras desconhecidas viram nomes literais.' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'Listas são unidas com + ou , (ex.: --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Datas e tempos do arquivo:' ;;
				'File identity:') printf '%s' 'Identidade do arquivo:' ;;
				'Size and media dimensions:') printf '%s' 'Tamanho e dimensões de mídia:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Faixas de resolução usam a dimensão maior:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadados (requer exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Ferramentas ausentes são propostas para instalação no primeiro uso (init-system).' ;;
				'Modes') printf '%s' 'Modos' ;;
				'Filtering and processing') printf '%s' 'Filtragem e processamento' ;;
				'Destination and naming') printf '%s' 'Destino e nomenclatura' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadados' ;;
				'Archives') printf '%s' 'Arquivos compactados' ;;
				'Output and safety') printf '%s' 'Saída e segurança' ;;
				'Dynamic values') printf '%s' 'Valores dinâmicos' ;;
				'Examples') printf '%s' 'Exemplos' ;;
				'Summary') printf '%s' 'Resumo' ;;
				'Unsupported mode: %s') printf '%s' 'Modo não suportado: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Valor de --pause inválido: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred requer shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Não foi possível criar o diretório de destino: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Opção desconhecida: %s (ignorada)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Idioma não suportado: %s (veja --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Não é arquivo nem diretório: %s' ;;
				'Files to treat: %s') printf '%s' 'Arquivos a tratar: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Descompactação muito profunda: %s' ;;
				'Archive test failed: %s') printf '%s' 'Teste do arquivo falhou: %s' ;;
				'Extract failed: %s') printf '%s' 'Extração falhou: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> apagar o arquivo' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'A lixeira precisa de trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Extraído(%s) + para a lixeira: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Extraído(%s) + destruído: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Extraído(%s) + apagado: %s' ;;
				'Trash failed: %s') printf '%s' 'Lixeira falhou: %s' ;;
				'Shred failed: %s') printf '%s' 'Destruição falhou: %s' ;;
				'Delete failed: %s') printf '%s' 'Exclusão falhou: %s' ;;
				'Not a regular file: %s') printf '%s' 'Não é um arquivo regular: %s' ;;
				'No MIME type for: %s') printf '%s' 'Sem tipo MIME para: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Tipo ignorado (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Não foi possível criar um nome para: %s' ;;
				'Cannot create: %s') printf '%s' 'Não foi possível criar: %s' ;;
				'Same place: %s') printf '%s' 'Mesmo lugar: %s' ;;
				'Copy failed: %s') printf '%s' 'Cópia falhou: %s' ;;
				'Move failed: %s') printf '%s' 'Movimentação falhou: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: destino não encontrado: %s' ;;
				'Removed: %s') printf '%s' 'Removido: %s' ;;
				'Remove failed: %s') printf '%s' 'Remoção falhou: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: destino não encontrado: %s' ;;
				'Trashed: %s') printf '%s' 'Para a lixeira: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: destino não encontrado: %s' ;;
				'Shredded: %s') printf '%s' 'Destruído: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadados removidos: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Não foi possível remover os metadados: %s' ;;
				'Copied : %s') printf '%s' 'Copiados : %s' ;;
				'Moved  : %s') printf '%s' 'Movidos  : %s' ;;
				'Removed: %s') printf '%s' 'Removidos: %s' ;;
				'Extracted: %s') printf '%s' 'Extraídos: %s' ;;
				'Preview: %s') printf '%s' 'Prévia: %s' ;;
				'Skipped: %s') printf '%s' 'Ignorados: %s' ;;
				'Failed : %s') printf '%s' 'Falhas  : %s' ;;
				'Nothing to treat.') printf '%s' 'Nada a tratar.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Classificando %s arquivo(s) - modo: %s, threads: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Aguardando o término das tarefas em segundo plano...' ;;
				'Finished.') printf '%s' 'Concluído.' ;;
				'Terminated by user!') printf '%s' 'Interrompido pelo usuário!' ;;
				'deps: missing: %s') printf '%s' 'deps: ausentes: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: instalação proposta: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: instalar agora? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: não instalado (defina DEPS_YES=1 para instalar sem perguntar)' ;;
				'deps: skipped') printf '%s' 'deps: ignorado' ;;
				'deps: no supported package manager found') printf '%s' 'deps: nenhum gerenciador de pacotes suportado encontrado' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: sem como obter root (execute como root ou instale o sudo)' ;;
				'Error: ') printf '%s' 'Erro: ' ;;
				'Warning: ') printf '%s' 'Aviso: ' ;;
				'unknown camera') printf '%s' 'câmera desconhecida' ;;
				'unknown date') printf '%s' 'data desconhecida' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Idioma da interface (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Mostra a lista de idiomas' ;;
				'Languages') printf '%s' 'Idiomas' ;;
				'Available languages (--lang=XX):') printf '%s' 'Idiomas disponíveis (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(padrão)           Apenas pré-visualização - imprime origem <=> destino' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Copia cada arquivo para seu local classificado' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Move cada arquivo para seu local classificado' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Remove o arquivo no caminho TARGET calculado' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Apelido de --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Envia o destino calculado para a lixeira do desktop' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Executa shred -u -n 1 no destino calculado' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Forma longa de qualquer modo acima (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Apenas arquivos cujo tipo MIME contém VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Percorre os diretórios fornecidos em profundidade total' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Inclui arquivos e diretórios ocultos' ;;
				'--links            Include symbolic links') printf '%s' '--links            Inclui links simbólicos' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Espera após cada arquivo' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Tamanho do pool de threads (padrão: nproc, mín 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Diretório base da árvore classificada (padrão: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Componentes de diretório primários (padrão: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Componentes de diretório abaixo do primário' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Gera o nome do arquivo (sem extensão)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Gera a extensão (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Nome a partir de metadados embutidos (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   data EXIF de imagem, tags de áudio/vídeo)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Sobrescreve destinos existentes, senão nome único ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Adiciona níveis <Câmera>/<AAAA-MM-DD> para imagens' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Remove metadados EXIF/GPS dos destinos após copiar/mover' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Extrai compactados para um dir temporário e classifica o conteúdo' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (o próprio compactado é apagado após o sucesso;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred aplicam esse destino ao compactado)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNome = dir principal / arquivo único dentro do compactado' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Força saída colorida (autodetectada num tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Apelido de --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Detalhes por arquivo desligados; só resumo' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Detalhes por arquivo ligados (padrão)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Imprime o resumo (padrão)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Acrescenta uma linha por ação a FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Escreve um script de desfazer (padrão: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Lembrete curto' ;;
				'--help             This help') printf '%s' '--help             Esta ajuda' ;;
				'--version          Print the version') printf '%s' '--version          Imprime a versão' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		ru)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' отсутствует, и имя его пакета неизвестно' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - автономный многопоточный сортировщик' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Использование: Sort.sh [параметры] <файл|каталог> ...' ;;
				'Common starts:') printf '%s' 'Типичные запуски:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Используйте --help для полного списка параметров и динамических значений.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Раскладывает файлы по динамическому дереву каталогов, построенному' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'из MIME, дат, размеров, медиаразмеров, контрольных сумм и заголовков.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'ВАЖНО: remove/delete/trash/shred действуют по вычисленному пути' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'TARGET, а не по источнику. Источник = цель отклоняется. Проверьте' ;;
				'preview output before using a destructive mode.') printf '%s' 'вывод предпросмотра перед деструктивным режимом.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Ключевые слова для --dirs, --subdirs, --rename и --extension' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'без учёта регистра. Неизвестные слова становятся буквальными именами.' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'Списки соединяются + или , (напр. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Даты и времена файла:' ;;
				'File identity:') printf '%s' 'Идентификация файла:' ;;
				'Size and media dimensions:') printf '%s' 'Размер и медиаразмеры:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Уровни разрешения определяются большей стороной:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Метаданные (нужен exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Отсутствующие инструменты предлагается установить при первом использовании (init-system).' ;;
				'Modes') printf '%s' 'Режимы' ;;
				'Filtering and processing') printf '%s' 'Фильтрация и обработка' ;;
				'Destination and naming') printf '%s' 'Назначение и именование' ;;
				'EXIF / metadata') printf '%s' 'EXIF / метаданные' ;;
				'Archives') printf '%s' 'Архивы' ;;
				'Output and safety') printf '%s' 'Вывод и безопасность' ;;
				'Dynamic values') printf '%s' 'Динамические значения' ;;
				'Examples') printf '%s' 'Примеры' ;;
				'Summary') printf '%s' 'Итоги' ;;
				'Unsupported mode: %s') printf '%s' 'Неподдерживаемый режим: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Недопустимое значение --pause: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred требует shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Не удалось создать целевой каталог: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Неизвестный параметр: %s (проигнорирован)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Неподдерживаемый язык: %s (см. --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Не файл и не каталог: %s' ;;
				'Files to treat: %s') printf '%s' 'Файлов к обработке: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Слишком глубокая распаковка: %s' ;;
				'Archive test failed: %s') printf '%s' 'Проверка архива не пройдена: %s' ;;
				'Extract failed: %s') printf '%s' 'Распаковка не удалась: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> удалить архив' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Корзине нужен trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Извлечено(%s) + в корзину: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Извлечено(%s) + уничтожено: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Извлечено(%s) + удалено: %s' ;;
				'Trash failed: %s') printf '%s' 'Сбой корзины: %s' ;;
				'Shred failed: %s') printf '%s' 'Сбой уничтожения: %s' ;;
				'Delete failed: %s') printf '%s' 'Сбой удаления: %s' ;;
				'Not a regular file: %s') printf '%s' 'Не обычный файл: %s' ;;
				'No MIME type for: %s') printf '%s' 'Нет MIME-типа для: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Пропуск типа (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Не удалось построить имя для: %s' ;;
				'Cannot create: %s') printf '%s' 'Не удалось создать: %s' ;;
				'Same place: %s') printf '%s' 'То же место: %s' ;;
				'Copy failed: %s') printf '%s' 'Сбой копирования: %s' ;;
				'Move failed: %s') printf '%s' 'Сбой перемещения: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Удаление: цель не найдена: %s' ;;
				'Removed: %s') printf '%s' 'Удалено: %s' ;;
				'Remove failed: %s') printf '%s' 'Сбой удаления: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Корзина: цель не найдена: %s' ;;
				'Trashed: %s') printf '%s' 'В корзине: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Уничтожение: цель не найдена: %s' ;;
				'Shredded: %s') printf '%s' 'Уничтожено: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Метаданные удалены: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Не удалось удалить метаданные: %s' ;;
				'Copied : %s') printf '%s' 'Скопировано : %s' ;;
				'Moved  : %s') printf '%s' 'Перемещено : %s' ;;
				'Removed: %s') printf '%s' 'Удалено: %s' ;;
				'Extracted: %s') printf '%s' 'Извлечено: %s' ;;
				'Preview: %s') printf '%s' 'Предпросмотр: %s' ;;
				'Skipped: %s') printf '%s' 'Пропущено: %s' ;;
				'Failed : %s') printf '%s' 'Сбоев : %s' ;;
				'Nothing to treat.') printf '%s' 'Нечего обрабатывать.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Сортировка %s файл(ов) - режим: %s, потоков: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Ожидание завершения фоновых задач...' ;;
				'Finished.') printf '%s' 'Готово.' ;;
				'Terminated by user!') printf '%s' 'Прервано пользователем!' ;;
				'deps: missing: %s') printf '%s' 'deps: отсутствуют: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: предложение установить: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: установить сейчас? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: не установлено (задайте DEPS_YES=1 для установки без запроса)' ;;
				'deps: skipped') printf '%s' 'deps: пропущено' ;;
				'deps: no supported package manager found') printf '%s' 'deps: поддерживаемый менеджер пакетов не найден' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: нет способа получить root (запустите от root или установите sudo)' ;;
				'Error: ') printf '%s' 'Ошибка: ' ;;
				'Warning: ') printf '%s' 'Предупреждение: ' ;;
				'unknown camera') printf '%s' 'неизвестная камера' ;;
				'unknown date') printf '%s' 'неизвестная дата' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Язык интерфейса (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Показать список языков' ;;
				'Languages') printf '%s' 'Языки' ;;
				'Available languages (--lang=XX):') printf '%s' 'Доступные языки (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(по умолчанию)     Только предпросмотр - печатает источник <=> цель' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Копирует каждый файл в его отсортированное расположение' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Перемещает каждый файл в его отсортированное расположение' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Удаляет файл по вычисленному пути TARGET' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Псевдоним --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Отправляет вычисленную цель в корзину рабочего стола' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Запускает shred -u -n 1 на вычисленной цели' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Длинная форма любого режима выше (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Только файлы, чей MIME-тип содержит VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Обходит указанные каталоги на всю глубину' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Включает скрытые файлы и каталоги' ;;
				'--links            Include symbolic links') printf '%s' '--links            Включает символические ссылки' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Пауза после каждого файла' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Размер пула потоков (по умолчанию: nproc, мин. 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Базовый каталог дерева сортировки (по умолчанию: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Первичные компоненты каталогов (по умолчанию: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Компоненты каталогов под первичными' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Формирует имя файла (без расширения)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Формирует расширение (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Имя из встроенных метаданных (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   EXIF-дата изображения, теги аудио/видео)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Перезаписывает существующие цели, иначе уникальное имя ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Добавляет уровни <Камера>/<ГГГГ-ММ-ДД> для изображений' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Удаляет EXIF/GPS-метаданные целей после копирования/перемещения' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Распаковывает архивы во временный каталог и сортирует содержимое' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (сам архив после успеха удаляется;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred применяют эту участь к архиву)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedИмя = главный каталог / единственный файл внутри архива' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Принудительно цветной вывод (автоопределение на tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Псевдоним --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Сведения по файлам выключены; только итоги' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Сведения по файлам включены (по умолчанию)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Печатает итоги (по умолчанию)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Дописывает строку за каждое действие в FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Пишет скрипт отмены (по умолчанию: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Краткая памятка' ;;
				'--help             This help') printf '%s' '--help             Эта справка' ;;
				'--version          Print the version') printf '%s' '--version          Печатает версию' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		ur)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' غائب ہے اور اس کا پیکج نام نامعلوم ہے' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - خود انحصار ملٹی تھریڈ منتظم' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'استعمال: Sort.sh [اختیارات] <فائل|ڈائریکٹری> ...' ;;
				'Common starts:') printf '%s' 'عام آغاز:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'مکمل آپشن فہرست اور متحرک اقدار کے لیے --help استعمال کریں۔' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'فائلوں کو MIME، تاریخوں، سائز، میڈیا ابعاد، چیک سم اور' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'میٹا ڈیٹا عنوانات سے بنے متحرک ڈائریکٹری درخت میں مرتب کرتا ہے۔' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'اہم: remove/delete/trash/shred حساب شدہ ہدف (TARGET) پر' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'عمل کرتے ہیں، ماخذ پر نہیں۔ ماخذ = ہدف مسترد ہے۔ تباہ کن موڈ' ;;
				'preview output before using a destructive mode.') printf '%s' 'استعمال کرنے سے پہلے پیش نظارہ دیکھ لیں۔' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs، --subdirs، --rename اور --extension کے کلیدی' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'الفاظ کے لیے حروف بزرگ/چھوٹے یکساں ہیں۔ نامعلوم الفاظ لفظی نام بنتے ہیں۔ فہرستیں' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '+ یا , سے جوڑی جاتی ہیں (مثلاً --dirs=year+month --subdirs=format,size)۔' ;;
				'Date and file times:') printf '%s' 'تاریخ اور فائل کے اوقات:' ;;
				'File identity:') printf '%s' 'فائل کی شناخت:' ;;
				'Size and media dimensions:') printf '%s' 'سائز اور میڈیا ابعاد:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'ریزولوشن درجات بڑے طول و عرض سے طے ہوتے ہیں:' ;;
				'Metadata (needs exiftool):') printf '%s' 'میٹا ڈیٹا (exiftool درکار):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'غائب اوزار پہلے استعمال پر انسٹالیشن کے لیے تجویز ہوتے ہیں (init-system)۔' ;;
				'Modes') printf '%s' 'موڈ' ;;
				'Filtering and processing') printf '%s' 'فلٹرنگ اور پروسیسنگ' ;;
				'Destination and naming') printf '%s' 'ہدف اور نامگذاری' ;;
				'EXIF / metadata') printf '%s' 'EXIF / میٹا ڈیٹا' ;;
				'Archives') printf '%s' 'آرکائیوز' ;;
				'Output and safety') printf '%s' 'آؤٹ پٹ اور حفاظت' ;;
				'Dynamic values') printf '%s' 'متحرک اقدار' ;;
				'Examples') printf '%s' 'مثالیں' ;;
				'Summary') printf '%s' 'خلاصہ' ;;
				'Unsupported mode: %s') printf '%s' 'غیر معاون موڈ: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'غلط --pause قدر: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred کو shred (coreutils) درکار ہے' ;;
				'Cannot create target directory: %s') printf '%s' 'ہدف ڈائریکٹری نہیں بن سکی: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'نامعلوم آپشن: %s (نظر انداز کیا گیا)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'غیر معاون زبان: %s (دیکھیں --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'فائل یا ڈائریکٹری نہیں: %s' ;;
				'Files to treat: %s') printf '%s' 'مشمولہ فائلیں: %s' ;;
				'Decompression too deep: %s') printf '%s' 'ان زیپ بہت گہرا: %s' ;;
				'Archive test failed: %s') printf '%s' 'آرکائیو ٹیسٹ ناکام: %s' ;;
				'Extract failed: %s') printf '%s' 'ان زیپ ناکام: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> آرکائیو حذف کریں' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'ٹراش کو trash-put (trash-cli) درکار ہے' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'ان زیپ شدہ(%s) + ٹراش: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'ان زیپ شدہ(%s) + شریڈ: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'ان زیپ شدہ(%s) + حذف: %s' ;;
				'Trash failed: %s') printf '%s' 'ٹراش ناکام: %s' ;;
				'Shred failed: %s') printf '%s' 'شریڈ ناکام: %s' ;;
				'Delete failed: %s') printf '%s' 'حذف ناکام: %s' ;;
				'Not a regular file: %s') printf '%s' 'باقاعدہ فائل نہیں: %s' ;;
				'No MIME type for: %s') printf '%s' 'کوئی MIME قسم نہیں: %s' ;;
				'Type skip (%s): %s') printf '%s' 'قسم چھوڑی گئی (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'نام نہیں بن سکا: %s' ;;
				'Cannot create: %s') printf '%s' 'نہیں بن سکتا: %s' ;;
				'Same place: %s') printf '%s' 'ایک ہی جگہ: %s' ;;
				'Copy failed: %s') printf '%s' 'کاپی ناکام: %s' ;;
				'Move failed: %s') printf '%s' 'منتقلی ناکام: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: ہدف نہیں ملا: %s' ;;
				'Removed: %s') printf '%s' 'ہٹایا گیا: %s' ;;
				'Remove failed: %s') printf '%s' 'ہٹانا ناکام: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: ہدف نہیں ملا: %s' ;;
				'Trashed: %s') printf '%s' 'ٹراش: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: ہدف نہیں ملا: %s' ;;
				'Shredded: %s') printf '%s' 'شریڈ: %s' ;;
				'Stripped metadata: %s') printf '%s' 'میٹا ڈیٹا ہٹایا گیا: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'میٹا ڈیٹا نہیں ہٹا سکا: %s' ;;
				'Copied : %s') printf '%s' 'کاپی  : %s' ;;
				'Moved  : %s') printf '%s' 'منتقل : %s' ;;
				'Removed: %s') printf '%s' 'ہٹایا : %s' ;;
				'Extracted: %s') printf '%s' 'ان زیپ: %s' ;;
				'Preview: %s') printf '%s' 'پیش نظارہ: %s' ;;
				'Skipped: %s') printf '%s' 'چھوڑا : %s' ;;
				'Failed : %s') printf '%s' 'ناکام : %s' ;;
				'Nothing to treat.') printf '%s' 'کچھ کرنے کو نہیں۔' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '%s فائل(یں) مرتب ہو رہی ہیں - موڈ: %s، تھریڈز: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'پس منظر کے جوبس ختم ہونے کا انتظار...' ;;
				'Finished.') printf '%s' 'مکمل۔' ;;
				'Terminated by user!') printf '%s' 'صارف نے روک دیا!' ;;
				'deps: missing: %s') printf '%s' 'deps: غائب: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: تجویز کردہ انسٹال: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: ابھی انسٹال کریں؟ [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: انسٹال نہیں ہوا (بغیر پوچھے انسٹال کے لیے DEPS_YES=1 رکھیں)' ;;
				'deps: skipped') printf '%s' 'deps: چھوڑا گیا' ;;
				'deps: no supported package manager found') printf '%s' 'deps: کوئی معاون پیکج مینیجر نہیں ملا' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: روٹ تک رسائی کا راستہ نہیں (root کے طور پر چلائیں یا sudo انسٹال کریں)' ;;
				'Error: ') printf '%s' 'خرابی: ' ;;
				'Warning: ') printf '%s' 'انتباہ: ' ;;
				'unknown camera') printf '%s' 'نامعلوم کیمرہ' ;;
				'unknown date') printf '%s' 'نامعلوم تاریخ' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          انٹرفیس کی زبان (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             زبانوں کی فہرست دکھائیں' ;;
				'Languages') printf '%s' 'زبانیں' ;;
				'Available languages (--lang=XX):') printf '%s' 'دستیاب زبانیں (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(پہلے سے طے)      صرف پیش نظارہ - ماخذ <=> ہدف پرنٹ کریں' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             ہر فائل کو اس کی مرتب شدہ جگہ کاپی کرتا ہے' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             ہر فائل کو اس کی مرتب شدہ جگہ منتقل کرتا ہے' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           حساب شدہ ہدف (TARGET) راستے پر فائل ہٹاتا ہے' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove کا متبادل' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            حساب شدہ ہدف کو ڈیسک ٹاپ ٹراش میں بھیجتا ہے' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            حساب شدہ ہدف پر shred -u -n 1 چلاتا ہے' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       اوپر کے کسی موڈ کی طویل شکل (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       صرف وہ فائلیں جن کی MIME قسم میں VALUE ہو' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        دی گئی ڈائریکٹریوں کو مکمل گہرائی تک سیر کرتا ہے' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           چھپی ہوئی فائلیں اور ڈائریکٹریاں شامل کرتا ہے' ;;
				'--links            Include symbolic links') printf '%s' '--links            علامتی لنکس شامل کرتا ہے' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    ہر فائل کے بعد انتظار' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           تھریڈ پول کا سائز (پہلے سے طے: nproc، کم از کم 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       مرتب شدہ درخت کی بنیادی ڈائریکٹری (پہلے سے طے: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        بنیادی ڈائریکٹری اجزا (پہلے سے طے: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     بنیادی سطح کے نیچے ڈائریکٹری اجزا' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     فائل کا نام بناتا ہے (توسیع کے بغیر)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  توسیع بناتا ہے (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            فائل کا نام شامل میٹا ڈیٹا سے (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   تصویر کی EXIF تاریخ، آڈیو/ویڈیو ٹیگز)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          موجودہ اہداف پر لکھ دیتا ہے، ورنہ منفرد ~(N) نام' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             تصاویر کے لیے <کیمرہ>/<YYYY-MM-DD> سطحوں کا اضافہ' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            copy/move کے بعد اہداف سے EXIF/GPS میٹا ڈیٹا ہٹاتا ہے' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       آرکائیوز کو عارضی ڈائریکٹری میں کھول کر مواد مرتب کرتا ہے' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (کامیابی کے بعد آرکائیو خود حذف ہو جاتا ہے؛' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred یہ تقدیر اس کے بدلے استعمال کرتے ہیں)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedنام = آرکائیو کے اندر مرکزی ڈائریکٹری / واحد فائل' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          رنگین آؤٹ پٹ زبردستی (tty پر خودکار طور پر پہچانا جاتا ہے)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored کا متبادل' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            فی فائل تفصیلات بند؛ صرف خلاصہ' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          فی فائل تفصیلات آن (پہلے سے طے)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            خلاصہ پرنٹ کرتا ہے (پہلے سے طے)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         ہر عمل کی ایک سطر FILE میں شامل کرتا ہے' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      انڈو اسکرپٹ لکھتا ہے (پہلے سے طے: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            مختصر یاد دہانی' ;;
				'--help             This help') printf '%s' '--help             یہ مدد' ;;
				'--version          Print the version') printf '%s' '--version          ورژن پرنٹ کرتا ہے' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		id)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' hilang dan nama paketnya tidak diketahui' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - penyusun berkas multithread mandiri' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Penggunaan: Sort.sh [opsi] <berkas|direktori> ...' ;;
				'Common starts:') printf '%s' 'Awalan umum:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Gunakan --help untuk daftar opsi lengkap dan nilai dinamis.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Menyusun berkas ke dalam pohon direktori dinamis yang dibangun dari MIME, tanggal,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'ukuran, dimensi media, checksum, dan judul metadata.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'PENTING: remove/delete/trash/shred berlaku pada TARGET yang' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'dihitung, bukan pada sumber. Sumber = target ditolak. Tinjau keluaran' ;;
				'preview output before using a destructive mode.') printf '%s' 'pratinjau sebelum memakai mode destruktif.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Kata kunci untuk --dirs, --subdirs, --rename dan --extension' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'tidak peka huruf besar/kecil. Kata tak dikenal menjadi nama literal. Daftar' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'digabung dengan + atau , (mis. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Tanggal dan waktu berkas:' ;;
				'File identity:') printf '%s' 'Identitas berkas:' ;;
				'Size and media dimensions:') printf '%s' 'Ukuran dan dimensi media:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Tingkat resolusi memakai dimensi terbesar:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadata (butuh exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Alat yang hilang diajukan untuk dipasang pada pemakaian pertama (init-system).' ;;
				'Modes') printf '%s' 'Mode' ;;
				'Filtering and processing') printf '%s' 'Penyaringan dan pemrosesan' ;;
				'Destination and naming') printf '%s' 'Tujuan dan penamaan' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadata' ;;
				'Archives') printf '%s' 'Arsip' ;;
				'Output and safety') printf '%s' 'Keluaran dan keamanan' ;;
				'Dynamic values') printf '%s' 'Nilai dinamis' ;;
				'Examples') printf '%s' 'Contoh' ;;
				'Summary') printf '%s' 'Ringkasan' ;;
				'Unsupported mode: %s') printf '%s' 'Mode tidak didukung: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Nilai --pause tidak valid: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred membutuhkan shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Tidak dapat membuat direktori tujuan: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Opsi tidak dikenal: %s (diabaikan)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Bahasa tidak didukung: %s (lihat --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Bukan berkas atau direktori: %s' ;;
				'Files to treat: %s') printf '%s' 'Berkas untuk diproses: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Penguraian arsip terlalu dalam: %s' ;;
				'Archive test failed: %s') printf '%s' 'Uji arsip gagal: %s' ;;
				'Extract failed: %s') printf '%s' 'Ekstrak gagal: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> hapus arsip' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Trash membutuhkan trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Diekstrak(%s) + ke tempat sampah: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Diekstrak(%s) + dihancurkan: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Diekstrak(%s) + dihapus: %s' ;;
				'Trash failed: %s') printf '%s' 'Trash gagal: %s' ;;
				'Shred failed: %s') printf '%s' 'Shred gagal: %s' ;;
				'Delete failed: %s') printf '%s' 'Hapus gagal: %s' ;;
				'Not a regular file: %s') printf '%s' 'Bukan berkas reguler: %s' ;;
				'No MIME type for: %s') printf '%s' 'Tidak ada tipe MIME untuk: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Lewati tipe (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Tidak dapat membentuk nama untuk: %s' ;;
				'Cannot create: %s') printf '%s' 'Tidak dapat membuat: %s' ;;
				'Same place: %s') printf '%s' 'Tempat yang sama: %s' ;;
				'Copy failed: %s') printf '%s' 'Salin gagal: %s' ;;
				'Move failed: %s') printf '%s' 'Pindah gagal: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: target tidak ditemukan: %s' ;;
				'Removed: %s') printf '%s' 'Dihapus: %s' ;;
				'Remove failed: %s') printf '%s' 'Penghapusan gagal: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: target tidak ditemukan: %s' ;;
				'Trashed: %s') printf '%s' 'Ke tempat sampah: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: target tidak ditemukan: %s' ;;
				'Shredded: %s') printf '%s' 'Dihancurkan: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadata dilepas: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Metadata tidak dapat dilepas: %s' ;;
				'Copied : %s') printf '%s' 'Disalin  : %s' ;;
				'Moved  : %s') printf '%s' 'Dipindah : %s' ;;
				'Removed: %s') printf '%s' 'Dihapus : %s' ;;
				'Extracted: %s') printf '%s' 'Diekstrak: %s' ;;
				'Preview: %s') printf '%s' 'Pratinjau: %s' ;;
				'Skipped: %s') printf '%s' 'Dilewati: %s' ;;
				'Failed : %s') printf '%s' 'Gagal    : %s' ;;
				'Nothing to treat.') printf '%s' 'Tidak ada yang perlu diproses.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Menyusun %s berkas - mode: %s, thread: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Menunggu pekerjaan latar belakang selesai...' ;;
				'Finished.') printf '%s' 'Selesai.' ;;
				'Terminated by user!') printf '%s' 'Dihentikan oleh pengguna!' ;;
				'deps: missing: %s') printf '%s' 'deps: hilang: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: usulan pemasangan: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: pasang sekarang? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: tidak dipasang (set DEPS_YES=1 untuk memasang tanpa bertanya)' ;;
				'deps: skipped') printf '%s' 'deps: dilewati' ;;
				'deps: no supported package manager found') printf '%s' 'deps: tidak ada manajer paket yang didukung' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: tidak ada cara memperoleh akses root (jalankan sebagai root atau pasang sudo)' ;;
				'Error: ') printf '%s' 'Kesalahan: ' ;;
				'Warning: ') printf '%s' 'Peringatan: ' ;;
				'unknown camera') printf '%s' 'kamera tidak dikenal' ;;
				'unknown date') printf '%s' 'tanggal tidak dikenal' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Bahasa antarmuka (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Cetak daftar bahasa' ;;
				'Languages') printf '%s' 'Bahasa' ;;
				'Available languages (--lang=XX):') printf '%s' 'Bahasa yang tersedia (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(bawaan)           Hanya pratinjau - cetak sumber <=> target' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Menyalin setiap berkas ke lokasi tersusunnya' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Memindahkan setiap berkas ke lokasi tersusunnya' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Menghapus berkas pada jalur TARGET yang dihitung' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias untuk --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Mengirim target yang dihitung ke tempat sampah desktop' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Menjalankan shred -u -n 1 pada target yang dihitung' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Bentuk panjang salah satu mode di atas (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Hanya berkas dengan tipe MIME yang memuat VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Menelusuri direktori yang diberikan sampai kedalaman penuh' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Menyertakan berkas dan direktori tersembunyi' ;;
				'--links            Include symbolic links') printf '%s' '--links            Menyertakan tautan simbolik' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Menunggu setelah setiap berkas' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Ukuran pool thread (bawaan: nproc, min 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Direktori dasar pohon tersusun (bawaan: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Komponen direktori utama (bawaan: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Komponen direktori di bawah tingkat utama' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Membentuk nama berkas (tanpa ekstensi)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Membentuk ekstensi (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Nama berkas dari metadata tersemat (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   tanggal EXIF gambar, tag audio/video)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Menimpa target yang ada, jika tidak nama ~(N) unik' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Menambah tingkat <Kamera>/<YYYY-MM-DD> untuk gambar' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Melepas metadata EXIF/GPS dari target setelah copy/move' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Mengekstrak arsip ke dir sementara dan menyusun isinya' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (arsipnya sendiri dihapus setelah sukses;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred menerapkan nasib itu sebagai gantinya)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNama = direktori utama / berkas tunggal di dalam arsip' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Memaksa keluaran berwarna (terdeteksi otomatis pada tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias untuk --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Detail per berkas mati; ringkasan saja' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Detail per berkas nyala (bawaan)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Mencetak ringkasan (bawaan)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Menambah satu baris per aksi ke FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Menulis skrip undo (bawaan: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Pengingat singkat' ;;
				'--help             This help') printf '%s' '--help             Bantuan ini' ;;
				'--version          Print the version') printf '%s' '--version          Mencetak versi' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		de)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' fehlt und sein Paketname ist unbekannt' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - eigenständiger Sortierer mit Threads' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Aufruf: Sort.sh [Optionen] <Datei|Verzeichnis> ...' ;;
				'Common starts:') printf '%s' 'Häufige Aufrufe:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Verwenden Sie --help für die vollständige Optionsliste und dynamische Werte.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Sortiert Dateien in einen dynamischen Verzeichnisbaum aus MIME, Daten,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'Größen, Medienabmessungen, Prüfsummen und Metadaten-Titeln.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'WICHTIG: remove/delete/trash/shred wirken auf den berechneten Zielpfad,' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'nicht auf die Quelle. Quelle = Ziel wird abgelehnt. Prüfen Sie die' ;;
				'preview output before using a destructive mode.') printf '%s' 'Vorschau-Ausgabe, bevor Sie einen destruktiven Modus verwenden.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Groß-/Kleinschreibung ist egal bei Schlüsselwörtern für --dirs, --subdirs,' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '--rename und --extension. Unbekannte Wörter werden wörtliche Namen. Listen' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'werden mit + oder , verbunden (z.B. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Datum und Dateizeiten:' ;;
				'File identity:') printf '%s' 'Datei-Identität:' ;;
				'Size and media dimensions:') printf '%s' 'Größe und Medienabmessungen:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Auflösungsstufen verwenden die größere Abmessung:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadaten (benötigt exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Fehlende Werkzeuge werden beim ersten Gebrauch zur Installation vorgeschlagen (init-system).' ;;
				'Modes') printf '%s' 'Modi' ;;
				'Filtering and processing') printf '%s' 'Filterung und Verarbeitung' ;;
				'Destination and naming') printf '%s' 'Ziel und Benennung' ;;
				'EXIF / metadata') printf '%s' 'EXIF / Metadaten' ;;
				'Archives') printf '%s' 'Archive' ;;
				'Output and safety') printf '%s' 'Ausgabe und Sicherheit' ;;
				'Dynamic values') printf '%s' 'Dynamische Werte' ;;
				'Examples') printf '%s' 'Beispiele' ;;
				'Summary') printf '%s' 'Zusammenfassung' ;;
				'Unsupported mode: %s') printf '%s' 'Nicht unterstützter Modus: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Ungültiger --pause-Wert: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred benötigt shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Zielverzeichnis kann nicht erstellt werden: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Unbekannte Option: %s (ignoriert)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Nicht unterstützte Sprache: %s (siehe --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Keine Datei oder kein Verzeichnis: %s' ;;
				'Files to treat: %s') printf '%s' 'Zu behandelnde Dateien: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Entpacken zu tief verschachtelt: %s' ;;
				'Archive test failed: %s') printf '%s' 'Archivtest fehlgeschlagen: %s' ;;
				'Extract failed: %s') printf '%s' 'Entpacken fehlgeschlagen: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> Archiv löschen' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Papierkorb benötigt trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Entpackt(%s) + in den Papierkorb: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Entpackt(%s) + geschreddert: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Entpackt(%s) + gelöscht: %s' ;;
				'Trash failed: %s') printf '%s' 'Papierkorb fehlgeschlagen: %s' ;;
				'Shred failed: %s') printf '%s' 'Shred fehlgeschlagen: %s' ;;
				'Delete failed: %s') printf '%s' 'Löschen fehlgeschlagen: %s' ;;
				'Not a regular file: %s') printf '%s' 'Keine reguläre Datei: %s' ;;
				'No MIME type for: %s') printf '%s' 'Kein MIME-Typ für: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Typ übersprungen (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Kann keinen Namen bilden für: %s' ;;
				'Cannot create: %s') printf '%s' 'Kann nicht erstellt werden: %s' ;;
				'Same place: %s') printf '%s' 'Gleicher Ort: %s' ;;
				'Copy failed: %s') printf '%s' 'Kopieren fehlgeschlagen: %s' ;;
				'Move failed: %s') printf '%s' 'Verschieben fehlgeschlagen: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: Ziel nicht gefunden: %s' ;;
				'Removed: %s') printf '%s' 'Entfernt: %s' ;;
				'Remove failed: %s') printf '%s' 'Entfernen fehlgeschlagen: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: Ziel nicht gefunden: %s' ;;
				'Trashed: %s') printf '%s' 'In den Papierkorb gelegt: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: Ziel nicht gefunden: %s' ;;
				'Shredded: %s') printf '%s' 'Geschreddert: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadaten entfernt: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Metadaten konnten nicht entfernt werden: %s' ;;
				'Copied : %s') printf '%s' 'Kopiert    : %s' ;;
				'Moved  : %s') printf '%s' 'Verschoben : %s' ;;
				'Removed: %s') printf '%s' 'Entfernt   : %s' ;;
				'Extracted: %s') printf '%s' 'Entpackt: %s' ;;
				'Preview: %s') printf '%s' 'Vorschau: %s' ;;
				'Skipped: %s') printf '%s' 'Übersprungen: %s' ;;
				'Failed : %s') printf '%s' 'Fehlgeschlagen: %s' ;;
				'Nothing to treat.') printf '%s' 'Nichts zu behandeln.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Sortiere %s Datei(en) - Modus: %s, Threads: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Warte auf den Abschluss der Hintergrund-Jobs...' ;;
				'Finished.') printf '%s' 'Fertig.' ;;
				'Terminated by user!') printf '%s' 'Vom Benutzer abgebrochen!' ;;
				'deps: missing: %s') printf '%s' 'deps: fehlt: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: Installationsvorschlag: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: jetzt installieren? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: nicht installiert (DEPS_YES=1 setzt Installation ohne Nachfrage)' ;;
				'deps: skipped') printf '%s' 'deps: übersprungen' ;;
				'deps: no supported package manager found') printf '%s' 'deps: kein unterstützter Paketmanager gefunden' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: kein Weg zu Root-Rechten (als Root ausführen oder sudo installieren)' ;;
				'Error: ') printf '%s' 'Fehler: ' ;;
				'Warning: ') printf '%s' 'Warnung: ' ;;
				'unknown camera') printf '%s' 'unbekannte Kamera' ;;
				'unknown date') printf '%s' 'unbekanntes Datum' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Oberflächensprache (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Sprachliste anzeigen' ;;
				'Languages') printf '%s' 'Sprachen' ;;
				'Available languages (--lang=XX):') printf '%s' 'Verfügbare Sprachen (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(Standard)         Nur Vorschau - gibt Quelle <=> Ziel aus' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Kopiert jede Datei an ihren sortierten Ort' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Verschiebt jede Datei an ihren sortierten Ort' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Entfernt die Datei am berechneten Zielpfad (TARGET)' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias für --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Legt das berechnete Ziel in den Desktop-Papierkorb' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Führt shred -u -n 1 auf dem berechneten Ziel aus' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Langform eines der Modi oben (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Nur Dateien, deren MIME-Typ VALUE enthält' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Durchläuft angegebene Verzeichnisse bis in volle Tiefe' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Schließt versteckte Dateien und Verzeichnisse ein' ;;
				'--links            Include symbolic links') printf '%s' '--links            Schließt symbolische Links ein' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Wartet nach jeder Datei' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Thread-Pool-Größe (Standard: nproc, min. 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Basisverzeichnis des sortierten Baums (Standard: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Primäre Verzeichnisbestandteile (Standard: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Verzeichnisbestandteile unter der primären Ebene' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Erzeugt den Dateinamen (ohne Erweiterung)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Erzeugt die Erweiterung (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Dateiname aus eingebetteten Metadaten (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   EXIF-Datum von Bildern, Audio-/Video-Tags)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Überschreibt vorhandene Ziele, sonst eindeutiger ~(N)-Name' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Ergänzt <Kamera>/<YYYY-MM-DD>-Ebenen für Bilder' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Entfernt EXIF/GPS-Metadaten aus Zielen nach copy/move' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Entpackt Archive in ein Temp-Verzeichnis und sortiert die Inhalte' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (das Archiv selbst wird nach Erfolg gelöscht;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred wenden dieses Schicksal stattdessen an)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedName = Hauptverzeichnis / einzelne Datei im Archiv' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Erzwingt farbige Ausgabe (auf einem tty automatisch erkannt)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias für --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Details pro Datei aus; nur Zusammenfassung' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Details pro Datei an (Standard)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Gibt die Zusammenfassung aus (Standard)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Hängt eine Zeile pro Aktion an FILE an' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Schreibt ein Undo-Skript (Standard: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Kurze Erinnerung' ;;
				'--help             This help') printf '%s' '--help             Diese Hilfe' ;;
				'--version          Print the version') printf '%s' '--version          Gibt die Version aus' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		ja)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' が不足しており、そのパッケージ名は不明です' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - 自己完結型マルチスレッド整理ツール' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' '使い方: Sort.sh [オプション] <ファイル|ディレクトリ> ...' ;;
				'Common starts:') printf '%s' 'よく使う起動例:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'オプション一覧と動的な値は --help をご利用ください。' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'MIME・日付・サイズ・メディア寸法・チェックサム・' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'メタデータのタイトルから動的なディレクトリツリーを作り、ファイルを整理します。' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' '重要: remove/delete/trash/shred は計算されたターゲット(TARGET)' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'パスに作用し、元ファイルには作用しません。元=ターゲットは拒否されます。' ;;
				'preview output before using a destructive mode.') printf '%s' '破壊的なモードを使う前にプレビュー出力を確認してください。' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs、--subdirs、--rename、--extension のキーワードは' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '大文字小文字を区別しません。未知の語はそのまま名前になります。リストは' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '+ または , で連結します(例: --dirs=year+month --subdirs=format,size)。' ;;
				'Date and file times:') printf '%s' '日付とファイル時刻:' ;;
				'File identity:') printf '%s' 'ファイル識別:' ;;
				'Size and media dimensions:') printf '%s' 'サイズとメディア寸法:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' '解像度の段階は長い辺で判定します:' ;;
				'Metadata (needs exiftool):') printf '%s' 'メタデータ(exiftool が必要):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' '不足ツールは初回使用時にインストールを提案します(init-system)。' ;;
				'Modes') printf '%s' 'モード' ;;
				'Filtering and processing') printf '%s' 'フィルタと処理' ;;
				'Destination and naming') printf '%s' '出力先と命名' ;;
				'EXIF / metadata') printf '%s' 'EXIF / メタデータ' ;;
				'Archives') printf '%s' 'アーカイブ' ;;
				'Output and safety') printf '%s' '出力と安全' ;;
				'Dynamic values') printf '%s' '動的な値' ;;
				'Examples') printf '%s' '例' ;;
				'Summary') printf '%s' '概要' ;;
				'Unsupported mode: %s') printf '%s' '未対応のモード: %s' ;;
				'Invalid --pause value: %s') printf '%s' '無効な --pause の値: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred には shred (coreutils) が必要です' ;;
				'Cannot create target directory: %s') printf '%s' 'ターゲットディレクトリを作成できません: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' '不明なオプション: %s (無視されました)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' '未対応の言語: %s (--lang を参照)' ;;
				'Not a file or directory: %s') printf '%s' 'ファイルでもディレクトリでもありません: %s' ;;
				'Files to treat: %s') printf '%s' '処理対象ファイル: %s' ;;
				'Decompression too deep: %s') printf '%s' '展開が深すぎます: %s' ;;
				'Archive test failed: %s') printf '%s' 'アーカイブのテストに失敗: %s' ;;
				'Extract failed: %s') printf '%s' '展開に失敗: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> アーカイブを削除' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'ゴミ箱には trash-put (trash-cli) が必要です' ;;
				'Extracted(%s) + trashed: %s') printf '%s' '展開済み(%s) + ゴミ箱へ: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' '展開済み(%s) + 完全消去: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' '展開済み(%s) + 削除: %s' ;;
				'Trash failed: %s') printf '%s' 'ゴミ箱へ移動できません: %s' ;;
				'Shred failed: %s') printf '%s' '完全消去に失敗: %s' ;;
				'Delete failed: %s') printf '%s' '削除に失敗: %s' ;;
				'Not a regular file: %s') printf '%s' '通常のファイルではありません: %s' ;;
				'No MIME type for: %s') printf '%s' 'MIME タイプが取得できません: %s' ;;
				'Type skip (%s): %s') printf '%s' 'タイプ除外 (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' '名前を生成できません: %s' ;;
				'Cannot create: %s') printf '%s' '作成できません: %s' ;;
				'Same place: %s') printf '%s' '同じ場所です: %s' ;;
				'Copy failed: %s') printf '%s' 'コピーに失敗: %s' ;;
				'Move failed: %s') printf '%s' '移動に失敗: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: 対象が見つかりません: %s' ;;
				'Removed: %s') printf '%s' '削除しました: %s' ;;
				'Remove failed: %s') printf '%s' '削除に失敗: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: 対象が見つかりません: %s' ;;
				'Trashed: %s') printf '%s' 'ゴミ箱へ: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: 対象が見つかりません: %s' ;;
				'Shredded: %s') printf '%s' '完全消去: %s' ;;
				'Stripped metadata: %s') printf '%s' 'メタデータを除去: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'メタデータを除去できません: %s' ;;
				'Copied : %s') printf '%s' 'コピー : %s' ;;
				'Moved  : %s') printf '%s' '移動   : %s' ;;
				'Removed: %s') printf '%s' '削除   : %s' ;;
				'Extracted: %s') printf '%s' '展開   : %s' ;;
				'Preview: %s') printf '%s' 'プレビュー: %s' ;;
				'Skipped: %s') printf '%s' '除外   : %s' ;;
				'Failed : %s') printf '%s' '失敗   : %s' ;;
				'Nothing to treat.') printf '%s' '処理するものがありません。' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '%s 個のファイルを整理中 - モード: %s、スレッド: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'バックグラウンドジョブの完了を待っています...' ;;
				'Finished.') printf '%s' '完了。' ;;
				'Terminated by user!') printf '%s' 'ユーザーによって中断されました!' ;;
				'deps: missing: %s') printf '%s' 'deps: 不足: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: インストール提案: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: 今インストールしますか? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: インストールされませんでした (確認なしで入れるには DEPS_YES=1)' ;;
				'deps: skipped') printf '%s' 'deps: スキップ' ;;
				'deps: no supported package manager found') printf '%s' 'deps: 対応するパッケージマネージャが見つかりません' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: root 権限を得る方法がありません (root で実行するか sudo を導入)' ;;
				'Error: ') printf '%s' 'エラー: ' ;;
				'Warning: ') printf '%s' '警告: ' ;;
				'unknown camera') printf '%s' '不明なカメラ' ;;
				'unknown date') printf '%s' '不明な日付' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          表示言語 (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             言語一覧を表示' ;;
				'Languages') printf '%s' '言語' ;;
				'Available languages (--lang=XX):') printf '%s' '利用可能な言語 (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(既定)             プレビューのみ - 元 <=> 先を表示' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             各ファイルを整理先へコピーします' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             各ファイルを整理先へ移動します' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           計算されたターゲット(TARGET)パスのファイルを削除します' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove の別名' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            計算されたターゲットをデスクトップのゴミ箱へ送ります' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            計算されたターゲットに shred -u -n 1 を実行します' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       上のモードのいずれかの長い形式 (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       MIME タイプに VALUE を含むファイルのみ' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        指定ディレクトリを最深部までたどります' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           隠しファイルと隠しディレクトリを含めます' ;;
				'--links            Include symbolic links') printf '%s' '--links            シンボリックリンクを含めます' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    各ファイルの後に待機します' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           スレッドプールのサイズ (既定: nproc、最小 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       整理ツリーの基準ディレクトリ (既定: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        第一階層のディレクトリ構成要素 (既定: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     第一階層の下のディレクトリ構成要素' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     ファイル名(拡張子なし)を生成します' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  拡張子を生成します (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            埋め込みメタデータからファイル名を生成 (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   画像の EXIF 日付、音声/動画のタグ)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          既存のターゲットを上書き、なければ一意な ~(N) 名' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             画像に <カメラ>/<YYYY-MM-DD> 階層を追加します' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            copy/move 後にターゲットから EXIF/GPS メタデータを除去します' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       アーカイブを一時ディレクトリへ展開し中身を整理します' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (成功後、アーカイブ自体は削除されます;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred は代わりにその運命を適用します)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressed名前 = アーカイブ内の主ディレクトリ / 単一ファイル' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          カラー出力を強制します (tty では自動判定)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored の別名' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            ファイルごとの詳細をオフ; 概要のみ' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          ファイルごとの詳細をオン (既定)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            概要を表示します (既定)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         操作ごとに 1 行を FILE に追記します' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      取り消しスクリプトを書き出します (既定: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            簡単な思い出し' ;;
				'--help             This help') printf '%s' '--help             このヘルプ' ;;
				'--version          Print the version') printf '%s' '--version          バージョンを表示します' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		tr)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' eksik ve paket adı bilinmiyor' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - kendi kendine yeten, çok iş parçacıklı düzenleyici' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Kullanım: Sort.sh [seçenekler] <dosya|dizin> ...' ;;
				'Common starts:') printf '%s' 'Sık kullanılan başlangıçlar:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Tam seçenek listesi ve dinamik değerler için --help kullanın.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Dosyaları MIME, tarihler, boyutlar, medya ölçüleri, sağlama' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'toplamları ve meta veri başlıklarından kurulan dinamik dizin ağacına düzenler.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'ÖNEMLİ: remove/delete/trash/shred hesaplanan HEDEF (TARGET)' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'yoluna etki eder, kaynağa değil. Kaynak = hedef reddedilir. Yıkıcı bir' ;;
				'preview output before using a destructive mode.') printf '%s' 'mod kullanmadan önce önizleme çıktısını gözden geçirin.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs, --subdirs, --rename ve --extension anahtar kelimelerinde' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'büyük/küçük harf önemsizdir. Bilinmeyen kelimeler gerçek ad olur. Listeler' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '+ veya , ile birleştirilir (örn. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Tarih ve dosya zamanları:' ;;
				'File identity:') printf '%s' 'Dosya kimliği:' ;;
				'Size and media dimensions:') printf '%s' 'Boyut ve medya ölçüleri:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Çözünürlük katmanları büyük ölçüye göre belirlenir:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Meta veri (exiftool gerekir):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Eksik araçlar ilk kullanımda kurulmak üzere önerilir (init-system).' ;;
				'Modes') printf '%s' 'Modlar' ;;
				'Filtering and processing') printf '%s' 'Filtreleme ve işleme' ;;
				'Destination and naming') printf '%s' 'Hedef ve adlandırma' ;;
				'EXIF / metadata') printf '%s' 'EXIF / meta veri' ;;
				'Archives') printf '%s' 'Arşivler' ;;
				'Output and safety') printf '%s' 'Çıktı ve güvenlik' ;;
				'Dynamic values') printf '%s' 'Dinamik değerler' ;;
				'Examples') printf '%s' 'Örnekler' ;;
				'Summary') printf '%s' 'Özet' ;;
				'Unsupported mode: %s') printf '%s' 'Desteklenmeyen mod: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Geçersiz --pause değeri: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred için shred (coreutils) gerekir' ;;
				'Cannot create target directory: %s') printf '%s' 'Hedef dizin oluşturulamıyor: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Bilinmeyen seçenek: %s (yoksayıldı)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Desteklenmeyen dil: %s (--lang bakın)' ;;
				'Not a file or directory: %s') printf '%s' 'Dosya veya dizin değil: %s' ;;
				'Files to treat: %s') printf '%s' 'İşlenecek dosyalar: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Açılamayı çok derin: %s' ;;
				'Archive test failed: %s') printf '%s' 'Arşiv testi başarısız: %s' ;;
				'Extract failed: %s') printf '%s' 'Çıkarma başarısız: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> arşivi sil' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Geri dönüşüm için trash-put (trash-cli) gerekir' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Açıldı(%s) + geri dönüşüme: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Açıldı(%s) + parçalandı: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Açıldı(%s) + silindi: %s' ;;
				'Trash failed: %s') printf '%s' 'Geri dönüşüm başarısız: %s' ;;
				'Shred failed: %s') printf '%s' 'Parçalama başarısız: %s' ;;
				'Delete failed: %s') printf '%s' 'Silme başarısız: %s' ;;
				'Not a regular file: %s') printf '%s' 'Normal bir dosya değil: %s' ;;
				'No MIME type for: %s') printf '%s' 'MIME türü yok: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Tür atlandı (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Ad oluşturulamıyor: %s' ;;
				'Cannot create: %s') printf '%s' 'Oluşturulamıyor: %s' ;;
				'Same place: %s') printf '%s' 'Aynı yer: %s' ;;
				'Copy failed: %s') printf '%s' 'Kopyalama başarısız: %s' ;;
				'Move failed: %s') printf '%s' 'Taşıma başarısız: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: hedef bulunamadı: %s' ;;
				'Removed: %s') printf '%s' 'Kaldırıldı: %s' ;;
				'Remove failed: %s') printf '%s' 'Kaldırma başarısız: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: hedef bulunamadı: %s' ;;
				'Trashed: %s') printf '%s' 'Geri dönüşüme: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: hedef bulunamadı: %s' ;;
				'Shredded: %s') printf '%s' 'Parçalandı: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Meta veri sıyırdı: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Meta veri sıyıramadı: %s' ;;
				'Copied : %s') printf '%s' 'Kopyalandı : %s' ;;
				'Moved  : %s') printf '%s' 'Taşındı   : %s' ;;
				'Removed: %s') printf '%s' 'Kaldırıldı: %s' ;;
				'Extracted: %s') printf '%s' 'Açıldı: %s' ;;
				'Preview: %s') printf '%s' 'Önizleme: %s' ;;
				'Skipped: %s') printf '%s' 'Atlandı: %s' ;;
				'Failed : %s') printf '%s' 'Başarısız : %s' ;;
				'Nothing to treat.') printf '%s' 'İşlenecek bir şey yok.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '%s dosya düzenleniyor - mod: %s, iş parçacığı: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Arka plan işlerinin bitmesi bekleniyor...' ;;
				'Finished.') printf '%s' 'Bitti.' ;;
				'Terminated by user!') printf '%s' 'Kullanıcı tarafından durduruldu!' ;;
				'deps: missing: %s') printf '%s' 'deps: eksik: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: önerilen kurulum: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: şimdi kurulsun mu? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: kurulmadı (sormadan kurmak için DEPS_YES=1 ayarlayın)' ;;
				'deps: skipped') printf '%s' 'deps: atlandı' ;;
				'deps: no supported package manager found') printf '%s' 'deps: desteklenen paket yöneticisi bulunamadı' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: root yetkisi yolu yok (root olarak çalıştırın veya sudo kurun)' ;;
				'Error: ') printf '%s' 'Hata: ' ;;
				'Warning: ') printf '%s' 'Uyarı: ' ;;
				'unknown camera') printf '%s' 'bilinmeyen kamera' ;;
				'unknown date') printf '%s' 'bilinmeyen tarih' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Arayüz dili (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Dil listesini yazdır' ;;
				'Languages') printf '%s' 'Diller' ;;
				'Available languages (--lang=XX):') printf '%s' 'Kullanılabilir diller (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(varsayılan)       Sadece önizleme - kaynak <=> hedef yazdırır' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Her dosyayı sıralı yerine kopyalar' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Her dosyayı sıralı yerine taşır' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Hesaplanan HEDEF (TARGET) yolundaki dosyayı kaldırır' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove için takma ad' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Hesaplanan hedefi masaüstü geri dönüşümüne gönderir' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Hesaplanan hedefte shred -u -n 1 çalıştırır' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Yukarıdaki modlardan birinin uzun biçimi (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Yalnızca MIME türü VALUE içeren dosyalar' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Verilen dizinleri en derine kadar gezer' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Gizli dosya ve dizinleri kapsar' ;;
				'--links            Include symbolic links') printf '%s' '--links            Simgesel bağlantıları kapsar' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Her dosyadan sonra bekler' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           İş parçacığı havuzu boyutu (varsayılan: nproc, en az 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Sıralı ağacın taban dizini (varsayılan: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Birincil dizin bileşenleri (varsayılan: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Birincil düzeyin altındaki dizin bileşenleri' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Dosya adını üretir (uzantısız)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Uzantıyı üretir (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Gömülü meta veriden dosya adı (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   görüntü EXIF tarihi, ses/video etiketleri)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Var olan hedeflerin üzerine yazar, yoksa özgün ~(N) ad' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Görüntüler için <Kamera>/<YYYY-MM-DD> düzeyleri ekler' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            copy/move sonrası hedeflerden EXIF/GPS meta verisini sıyırır' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Arşivleri geçici dizine açar ve içeriğini düzenler' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (başarıdan sonra arşivin kendisi silinir;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred bu akıbeti onun yerine uygular)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedAd = arşiv içindeki ana dizin / tek dosya' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Renkli çıktıyı zorlar (tty üzerinde otomatik algılanır)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored için takma ad' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Dosya başına ayrıntı kapalı; yalnızca özet' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Dosya başına ayrıntı açık (varsayılan)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Özeti yazdırır (varsayılan)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Her işlem için bir satırı FILE sonuna ekler' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Geri alma betiği yazar (varsayılan: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Kısa hatırlatma' ;;
				'--help             This help') printf '%s' '--help             Bu yardım' ;;
				'--version          Print the version') printf '%s' '--version          Sürümü yazdırır' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		ko)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\''이(가) 없으며 패키지 이름을 알 수 없습니다' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - 자체 완결형 멀티스레드 파일 정리 도구' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' '사용법: Sort.sh [옵션] <파일|디렉터리> ...' ;;
				'Common starts:') printf '%s' '자주 쓰는 시작 예:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' '전체 옵션 목록과 동적 값은 --help를 사용하세요.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'MIME, 날짜, 크기, 미디어 크기, 체크섬, 메타데이터 제목으로' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' '구성된 동적 디렉터리 트리에 파일을 정리합니다.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' '중요: remove/delete/trash/shred은 계산된 대상(TARGET)' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' '경로에 작용하며 원본에는 작용하지 않습니다. 원본 = 대상은 거부됩니다.' ;;
				'preview output before using a destructive mode.') printf '%s' '파괴적인 모드를 쓰기 전에 미리보기 출력을 확인하세요.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' '--dirs, --subdirs, --rename, --extension 키워드는' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' '대소문자를 구별하지 않습니다. 모르는 단어는 그대로 이름이 됩니다. 목록은' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' '+ 또는 ,로 연결합니다(예: --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' '날짜와 파일 시간:' ;;
				'File identity:') printf '%s' '파일 식별:' ;;
				'Size and media dimensions:') printf '%s' '크기와 미디어 크기:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' '해상도 등급은 긴 변을 기준으로 합니다:' ;;
				'Metadata (needs exiftool):') printf '%s' '메타데이터(exiftool 필요):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' '없는 도구는 처음 사용할 때 설치를 제안합니다(init-system).' ;;
				'Modes') printf '%s' '모드' ;;
				'Filtering and processing') printf '%s' '필터와 처리' ;;
				'Destination and naming') printf '%s' '대상과 이름짓기' ;;
				'EXIF / metadata') printf '%s' 'EXIF / 메타데이터' ;;
				'Archives') printf '%s' '아카이브' ;;
				'Output and safety') printf '%s' '출력과 안전' ;;
				'Dynamic values') printf '%s' '동적 값' ;;
				'Examples') printf '%s' '예시' ;;
				'Summary') printf '%s' '요약' ;;
				'Unsupported mode: %s') printf '%s' '지원하지 않는 모드: %s' ;;
				'Invalid --pause value: %s') printf '%s' '잘못된 --pause 값: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred에는 shred (coreutils)가 필요합니다' ;;
				'Cannot create target directory: %s') printf '%s' '대상 디렉터리를 만들 수 없습니다: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' '알 수 없는 옵션: %s (무시함)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' '지원하지 않는 언어: %s (--lang 참조)' ;;
				'Not a file or directory: %s') printf '%s' '파일이나 디렉터리가 아닙니다: %s' ;;
				'Files to treat: %s') printf '%s' '처리할 파일: %s' ;;
				'Decompression too deep: %s') printf '%s' '압축 해제가 너무 깊습니다: %s' ;;
				'Archive test failed: %s') printf '%s' '아카이브 검사 실패: %s' ;;
				'Extract failed: %s') printf '%s' '압축 해제 실패: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> 아카이브 삭제' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' '휴지통에는 trash-put (trash-cli)가 필요합니다' ;;
				'Extracted(%s) + trashed: %s') printf '%s' '해제됨(%s) + 휴지통: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' '해제됨(%s) + 완전삭제: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' '해제됨(%s) + 삭제: %s' ;;
				'Trash failed: %s') printf '%s' '휴지통 실패: %s' ;;
				'Shred failed: %s') printf '%s' '완전삭제 실패: %s' ;;
				'Delete failed: %s') printf '%s' '삭제 실패: %s' ;;
				'Not a regular file: %s') printf '%s' '일반 파일이 아닙니다: %s' ;;
				'No MIME type for: %s') printf '%s' 'MIME 타입 없음: %s' ;;
				'Type skip (%s): %s') printf '%s' '타입 제외 (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' '이름을 만들 수 없습니다: %s' ;;
				'Cannot create: %s') printf '%s' '만들 수 없습니다: %s' ;;
				'Same place: %s') printf '%s' '같은 위치: %s' ;;
				'Copy failed: %s') printf '%s' '복사 실패: %s' ;;
				'Move failed: %s') printf '%s' '이동 실패: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: 대상을 찾을 수 없습니다: %s' ;;
				'Removed: %s') printf '%s' '제거됨: %s' ;;
				'Remove failed: %s') printf '%s' '제거 실패: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: 대상을 찾을 수 없습니다: %s' ;;
				'Trashed: %s') printf '%s' '휴지통: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: 대상을 찾을 수 없습니다: %s' ;;
				'Shredded: %s') printf '%s' '완전삭제: %s' ;;
				'Stripped metadata: %s') printf '%s' '메타데이터 제거됨: %s' ;;
				'Could not strip metadata: %s') printf '%s' '메타데이터를 제거하지 못했습니다: %s' ;;
				'Copied : %s') printf '%s' '복사됨 : %s' ;;
				'Moved  : %s') printf '%s' '이동됨 : %s' ;;
				'Removed: %s') printf '%s' '제거됨 : %s' ;;
				'Extracted: %s') printf '%s' '해제됨 : %s' ;;
				'Preview: %s') printf '%s' '미리보기: %s' ;;
				'Skipped: %s') printf '%s' '건너뜀 : %s' ;;
				'Failed : %s') printf '%s' '실패   : %s' ;;
				'Nothing to treat.') printf '%s' '처리할 것이 없습니다.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' '파일 %s개 정리 중 - 모드: %s, 스레드: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' '백그라운드 작업이 끝나기를 기다리는 중...' ;;
				'Finished.') printf '%s' '완료.' ;;
				'Terminated by user!') printf '%s' '사용자가 중단했습니다!' ;;
				'deps: missing: %s') printf '%s' 'deps: 없음: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: 설치 제안: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: 지금 설치할까요? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: 설치되지 않았습니다 (물어보지 않고 설치하려면 DEPS_YES=1)' ;;
				'deps: skipped') printf '%s' 'deps: 건너뜀' ;;
				'deps: no supported package manager found') printf '%s' 'deps: 지원하는 패키지 관리자가 없습니다' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: root 권한을 얻을 방법이 없습니다 (root로 실행하거나 sudo 설치)' ;;
				'Error: ') printf '%s' '오류: ' ;;
				'Warning: ') printf '%s' '경고: ' ;;
				'unknown camera') printf '%s' '알 수 없는 카메라' ;;
				'unknown date') printf '%s' '알 수 없는 날짜' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          인터페이스 언어 (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             언어 목록 출력' ;;
				'Languages') printf '%s' '언어' ;;
				'Available languages (--lang=XX):') printf '%s' '사용 가능한 언어 (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(기본값)           미리보기만 - 원본 <=> 대상 출력' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             각 파일을 정리된 위치로 복사합니다' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             각 파일을 정리된 위치로 이동합니다' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           계산된 대상(TARGET) 경로의 파일을 제거합니다' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           --remove의 별칭' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            계산된 대상을 데스크톱 휴지통으로 보냅니다' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            계산된 대상에 shred -u -n 1을 실행합니다' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       위 모드의 긴 형식 (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       MIME 타입에 VALUE가 포함된 파일만' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        지정한 디렉터리를 끝까지 탐색합니다' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           숨김 파일과 숨김 디렉터리를 포함합니다' ;;
				'--links            Include symbolic links') printf '%s' '--links            심볼릭 링크를 포함합니다' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    각 파일 후에 대기합니다' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           스레드 풀 크기 (기본값: nproc, 최소 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       정리 트리의 기준 디렉터리 (기본값: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        1차 디렉터리 구성 요소 (기본값: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     1차 아래의 디렉터리 구성 요소' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     파일 이름(확장자 제외)을 생성합니다' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  확장자를 생성합니다 (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            내장 메타데이터에서 파일 이름 생성 (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   이미지 EXIF 날짜, 오디오/비디오 태그)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          기존 대상을 덮어쓰고, 없으면 고유한 ~(N) 이름' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             이미지에 <카메라>/<YYYY-MM-DD> 단계를 추가합니다' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            copy/move 후 대상에서 EXIF/GPS 메타데이터를 제거합니다' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       아카이브를 임시 디렉터리에 풀고 내용을 정리합니다' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (성공 후 아카이브 자체는 삭제됩니다;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred은 그 대신 그 운명을 적용합니다)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressed이름 = 아카이브 안의 기본 디렉터리 / 단일 파일' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          색상 출력을 강제합니다 (tty에서 자동 감지)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           --colored의 별칭' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            파일별 상세 끔; 요약만' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          파일별 상세 켬 (기본값)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            요약을 출력합니다 (기본값)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         작업마다 한 줄씩 FILE에 추가합니다' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      되돌리기 스크립트를 작성합니다 (기본값: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            간단한 요약' ;;
				'--help             This help') printf '%s' '--help             이 도움말' ;;
				'--version          Print the version') printf '%s' '--version          버전을 출력합니다' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		vi)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' bị thiếu và tên gói của nó không rõ' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - công cụ sắp xếp đa luồng tự chứa' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Cách dùng: Sort.sh [tùy chọn] <tệp|thư mục> ...' ;;
				'Common starts:') printf '%s' 'Khởi động thường dùng:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Dùng --help để xem đầy đủ danh sách tùy chọn và giá trị động.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Sắp xếp tệp vào cây thư mục động được dựng từ MIME, ngày tháng,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'kích thước, kích thước media, checksum và tiêu đề metadata.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'QUAN TRỌNG: remove/delete/trash/shred tác động lên ĐÍCH (TARGET)' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'đã tính, không phải nguồn. Nguồn = đích bị từ chối. Hãy xem đầu ra' ;;
				'preview output before using a destructive mode.') printf '%s' 'xem trước trước khi dùng chế độ phá hủy.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Từ khóa cho --dirs, --subdirs, --rename và --extension' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'không phân biệt hoa/thường. Từ lạ thành tên nguyên văn. Danh sách nối' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'bằng + hoặc , (vd. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Ngày và thời gian của tệp:' ;;
				'File identity:') printf '%s' 'Nhận dạng tệp:' ;;
				'Size and media dimensions:') printf '%s' 'Kích thước và kích thước media:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Bậc phân giải dùng chiều lớn hơn:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadata (cần exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Công cụ thiếu sẽ được đề nghị cài khi dùng lần đầu (init-system).' ;;
				'Modes') printf '%s' 'Chế độ' ;;
				'Filtering and processing') printf '%s' 'Lọc và xử lý' ;;
				'Destination and naming') printf '%s' 'Đích và đặt tên' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadata' ;;
				'Archives') printf '%s' 'Kho lưu trữ' ;;
				'Output and safety') printf '%s' 'Đầu ra và an toàn' ;;
				'Dynamic values') printf '%s' 'Giá trị động' ;;
				'Examples') printf '%s' 'Ví dụ' ;;
				'Summary') printf '%s' 'Tóm tắt' ;;
				'Unsupported mode: %s') printf '%s' 'Chế độ không được hỗ trợ: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Giá trị --pause không hợp lệ: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred cần shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Không tạo được thư mục đích: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Tùy chọn không rõ: %s (bỏ qua)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Ngôn ngữ không được hỗ trợ: %s (xem --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Không phải tệp hay thư mục: %s' ;;
				'Files to treat: %s') printf '%s' 'Tệp cần xử lý: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Giải nén quá sâu: %s' ;;
				'Archive test failed: %s') printf '%s' 'Kiểm tra kho thất bại: %s' ;;
				'Extract failed: %s') printf '%s' 'Giải nén thất bại: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> xóa kho' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Thùng rác cần trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Đã giải nén(%s) + thùng rác: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Đã giải nén(%s) + xóa sạch: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Đã giải nén(%s) + đã xóa: %s' ;;
				'Trash failed: %s') printf '%s' 'Thùng rác thất bại: %s' ;;
				'Shred failed: %s') printf '%s' 'Xóa sạch thất bại: %s' ;;
				'Delete failed: %s') printf '%s' 'Xóa thất bại: %s' ;;
				'Not a regular file: %s') printf '%s' 'Không phải tệp thường: %s' ;;
				'No MIME type for: %s') printf '%s' 'Không có kiểu MIME cho: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Bỏ qua kiểu (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Không tạo được tên cho: %s' ;;
				'Cannot create: %s') printf '%s' 'Không tạo được: %s' ;;
				'Same place: %s') printf '%s' 'Cùng chỗ: %s' ;;
				'Copy failed: %s') printf '%s' 'Sao chép thất bại: %s' ;;
				'Move failed: %s') printf '%s' 'Di chuyển thất bại: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: không thấy đích: %s' ;;
				'Removed: %s') printf '%s' 'Đã gỡ bỏ: %s' ;;
				'Remove failed: %s') printf '%s' 'Gỡ bỏ thất bại: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: không thấy đích: %s' ;;
				'Trashed: %s') printf '%s' 'Vào thùng rác: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: không thấy đích: %s' ;;
				'Shredded: %s') printf '%s' 'Đã xóa sạch: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Đã gỡ metadata: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Không gỡ được metadata: %s' ;;
				'Copied : %s') printf '%s' 'Đã sao chép : %s' ;;
				'Moved  : %s') printf '%s' 'Đã chuyển   : %s' ;;
				'Removed: %s') printf '%s' 'Đã gỡ bỏ    : %s' ;;
				'Extracted: %s') printf '%s' 'Đã giải nén: %s' ;;
				'Preview: %s') printf '%s' 'Xem trước: %s' ;;
				'Skipped: %s') printf '%s' 'Đã bỏ qua: %s' ;;
				'Failed : %s') printf '%s' 'Thất bại : %s' ;;
				'Nothing to treat.') printf '%s' 'Không có gì để xử lý.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Đang sắp xếp %s tệp - chế độ: %s, luồng: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Đang chờ các công việc nền kết thúc...' ;;
				'Finished.') printf '%s' 'Xong.' ;;
				'Terminated by user!') printf '%s' 'Bị người dùng dừng!' ;;
				'deps: missing: %s') printf '%s' 'deps: thiếu: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: đề nghị cài: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: cài ngay? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: chưa cài (đặt DEPS_YES=1 để cài không cần hỏi)' ;;
				'deps: skipped') printf '%s' 'deps: bỏ qua' ;;
				'deps: no supported package manager found') printf '%s' 'deps: không tìm thấy trình quản lý gói được hỗ trợ' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: không có cách lấy quyền root (chạy với root hoặc cài sudo)' ;;
				'Error: ') printf '%s' 'Lỗi: ' ;;
				'Warning: ') printf '%s' 'Cảnh báo: ' ;;
				'unknown camera') printf '%s' 'máy ảnh không rõ' ;;
				'unknown date') printf '%s' 'ngày không rõ' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Ngôn ngữ giao diện (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             In danh sách ngôn ngữ' ;;
				'Languages') printf '%s' 'Ngôn ngữ' ;;
				'Available languages (--lang=XX):') printf '%s' 'Các ngôn ngữ có sẵn (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(mặc định)         Chỉ xem trước - in nguồn <=> đích' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Sao chép mỗi tệp đến vị trí đã sắp của nó' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Chuyển mỗi tệp đến vị trí đã sắp của nó' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Gỡ tệp tại đường dẫn ĐÍCH (TARGET) đã tính' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Bí danh của --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Gửi đích đã tính vào thùng rác màn hình' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Chạy shred -u -n 1 trên đích đã tính' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Dạng dài của một chế độ ở trên (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Chỉ tệp có kiểu MIME chứa VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Duyệt các thư mục cho trước đến tận cùng' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Bao gồm tệp và thư mục ẩn' ;;
				'--links            Include symbolic links') printf '%s' '--links            Bao gồm liên kết tượng trưng' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Chờ sau mỗi tệp' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Kích thước nhóm luồng (mặc định: nproc, tối thiểu 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Thư mục gốc của cây sắp xếp (mặc định: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Thành phần thư mục chính (mặc định: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Thành phần thư mục dưới tầng chính' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Sinh tên tệp (không có phần mở rộng)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Sinh phần mở rộng (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Tên tệp từ metadata nhúng (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   ngày EXIF của ảnh, thẻ âm thanh/video)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Ghi đè đích đã có, nếu không tên ~(N) duy nhất' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Thêm tầng <Máy ảnh>/<YYYY-MM-DD> cho ảnh' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Gỡ metadata EXIF/GPS khỏi đích sau copy/move' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Giải nén kho vào thư mục tạm rồi sắp xếp nội dung' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (bản thân kho bị xóa sau khi thành công;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred áp số phận đó thay thế)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedTên = thư mục chính / tệp đơn trong kho' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Ép đầu ra có màu (tự dò trên tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Bí danh của --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Tắt chi tiết từng tệp; chỉ tóm tắt' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Bật chi tiết từng tệp (mặc định)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            In tóm tắt (mặc định)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Nối một dòng mỗi thao tác vào FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Viết script hoàn tác (mặc định: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Nhắc ngắn' ;;
				'--help             This help') printf '%s' '--help             Trợ giúp này' ;;
				'--version          Print the version') printf '%s' '--version          In phiên bản' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		it)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' manca e il nome del suo pacchetto è sconosciuto' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - organizzatore multithread autonomo' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Uso: Sort.sh [opzioni] <file|directory> ...' ;;
				'Common starts:') printf '%s' 'Avvii comuni:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Usa --help per l'\''elenco completo delle opzioni e i valori dinamici.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Ordina i file in un albero di directory dinamico costruito da MIME, date,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'dimensioni, dimensioni dei media, checksum e titoli dei metadati.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'IMPORTANTE: remove/delete/trash/shred agiscono sul PERCORSO DI' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'DESTINAZIONE calcolato, non sulla sorgente. Sorgente = destinazione è rifiutato.' ;;
				'preview output before using a destructive mode.') printf '%s' 'Esamina l'\''output di anteprima prima di usare una modalità distruttiva.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Le parole chiave per --dirs, --subdirs, --rename e --extension' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'non distinguono maiuscole/minuscole. Parole sconosciute diventano nomi letterali.' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'Gli elenchi si uniscono con + o , (es. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Data e orari del file:' ;;
				'File identity:') printf '%s' 'Identità del file:' ;;
				'Size and media dimensions:') printf '%s' 'Dimensione e dimensioni dei media:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'I livelli di risoluzione usano la dimensione maggiore:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadati (richiede exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Gli strumenti mancanti vengono proposti per l'\''installazione al primo uso (init-system).' ;;
				'Modes') printf '%s' 'Modalità' ;;
				'Filtering and processing') printf '%s' 'Filtraggio ed elaborazione' ;;
				'Destination and naming') printf '%s' 'Destinazione e denominazione' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadati' ;;
				'Archives') printf '%s' 'Archivi' ;;
				'Output and safety') printf '%s' 'Output e sicurezza' ;;
				'Dynamic values') printf '%s' 'Valori dinamici' ;;
				'Examples') printf '%s' 'Esempi' ;;
				'Summary') printf '%s' 'Riepilogo' ;;
				'Unsupported mode: %s') printf '%s' 'Modalità non supportata: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Valore --pause non valido: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred richiede shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Impossibile creare la directory di destinazione: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Opzione sconosciuta: %s (ignorata)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Lingua non supportata: %s (vedi --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Non è un file né una directory: %s' ;;
				'Files to treat: %s') printf '%s' 'File da trattare: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Estrazione troppo profonda: %s' ;;
				'Archive test failed: %s') printf '%s' 'Test dell'\''archivio fallito: %s' ;;
				'Extract failed: %s') printf '%s' 'Estrazione fallita: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> elimina l'\''archivio' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Il cestino richiede trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Estratto(%s) + nel cestino: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Estratto(%s) + distrutto: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Estratto(%s) + eliminato: %s' ;;
				'Trash failed: %s') printf '%s' 'Cestino fallito: %s' ;;
				'Shred failed: %s') printf '%s' 'Distruzione fallita: %s' ;;
				'Delete failed: %s') printf '%s' 'Eliminazione fallita: %s' ;;
				'Not a regular file: %s') printf '%s' 'Non è un file regolare: %s' ;;
				'No MIME type for: %s') printf '%s' 'Nessun tipo MIME per: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Tipo saltato (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Impossibile formare un nome per: %s' ;;
				'Cannot create: %s') printf '%s' 'Impossibile creare: %s' ;;
				'Same place: %s') printf '%s' 'Stesso posto: %s' ;;
				'Copy failed: %s') printf '%s' 'Copia fallita: %s' ;;
				'Move failed: %s') printf '%s' 'Spostamento fallito: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: destinazione non trovata: %s' ;;
				'Removed: %s') printf '%s' 'Rimosso: %s' ;;
				'Remove failed: %s') printf '%s' 'Rimozione fallita: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: destinazione non trovata: %s' ;;
				'Trashed: %s') printf '%s' 'Nel cestino: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: destinazione non trovata: %s' ;;
				'Shredded: %s') printf '%s' 'Distrutto: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadati rimossi: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Impossibile rimuovere i metadati: %s' ;;
				'Copied : %s') printf '%s' 'Copiati  : %s' ;;
				'Moved  : %s') printf '%s' 'Spostati : %s' ;;
				'Removed: %s') printf '%s' 'Rimossi  : %s' ;;
				'Extracted: %s') printf '%s' 'Estratti : %s' ;;
				'Preview: %s') printf '%s' 'Anteprima: %s' ;;
				'Skipped: %s') printf '%s' 'Saltati  : %s' ;;
				'Failed : %s') printf '%s' 'Falliti  : %s' ;;
				'Nothing to treat.') printf '%s' 'Niente da trattare.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Ordinamento di %s file - modalità: %s, thread: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'In attesa del termine dei lavori in background...' ;;
				'Finished.') printf '%s' 'Finito.' ;;
				'Terminated by user!') printf '%s' 'Interrotto dall'\''utente!' ;;
				'deps: missing: %s') printf '%s' 'deps: mancanti: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: installazione proposta: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: installare ora? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: non installato (imposta DEPS_YES=1 per installare senza chiedere)' ;;
				'deps: skipped') printf '%s' 'deps: saltato' ;;
				'deps: no supported package manager found') printf '%s' 'deps: nessun gestore di pacchetti supportato trovato' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: nessun modo per ottenere root (esegui come root o installa sudo)' ;;
				'Error: ') printf '%s' 'Errore: ' ;;
				'Warning: ') printf '%s' 'Attenzione: ' ;;
				'unknown camera') printf '%s' 'fotocamera sconosciuta' ;;
				'unknown date') printf '%s' 'data sconosciuta' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Lingua dell'\''interfaccia (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Stampa l'\''elenco delle lingue' ;;
				'Languages') printf '%s' 'Lingue' ;;
				'Available languages (--lang=XX):') printf '%s' 'Lingue disponibili (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(predefinito)       Solo anteprima - stampa sorgente <=> destinazione' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Copia ogni file nella sua posizione ordinata' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Sposta ogni file nella sua posizione ordinata' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Rimuove il file nel percorso DI DESTINAZIONE calcolato' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias per --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Manda la destinazione calcolata nel cestino del desktop' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Esegue shred -u -n 1 sulla destinazione calcolata' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Forma lunga di una delle modalità sopra (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Solo file il cui tipo MIME contiene VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Attraversa le directory fornite fino in profondità' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Include file e directory nascosti' ;;
				'--links            Include symbolic links') printf '%s' '--links            Include collegamenti simbolici' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Attende dopo ogni file' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Dimensione del pool di thread (predefinito: nproc, min 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Directory base dell'\''albero ordinato (predefinito: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Componenti directory primari (predefinito: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Componenti directory sotto il livello primario' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Genera il nome del file (senza estensione)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Genera l'\''estensione (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Nome del file dai metadati incorporati (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   data EXIF dell'\''immagine, tag audio/video)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Sovrascrive le destinazioni esistenti, altrimenti nome ~(N) unico' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Aggiunge livelli <Fotocamera>/<YYYY-MM-DD> per le immagini' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Rimuove i metadati EXIF/GPS dalle destinazioni dopo copy/move' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Estrae gli archivi in una dir temporanea e ordina il contenuto' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (l'\''archivio stesso viene eliminato dopo il successo;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred applicano tale sorte al suo posto)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNome = directory principale / file singolo dentro l'\''archivio' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Forza l'\''output colorato (rilevato automaticamente su un tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias per --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Dettagli per file disattivati; solo riepilogo' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Dettagli per file attivati (predefinito)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Stampa il riepilogo (predefinito)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Aggiunge una riga per azione a FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Scrive uno script di annullamento (predefinito: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Promemoria breve' ;;
				'--help             This help') printf '%s' '--help             Questo aiuto' ;;
				'--version          Print the version') printf '%s' '--version          Stampa la versione' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		pl)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' jest brakujące, a nazwa pakietu jest nieznana' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - samodzielny wielowątkowy organizator plików' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Użycie: Sort.sh [opcje] <plik|katalog> ...' ;;
				'Common starts:') printf '%s' 'Częste starty:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Użyj --help, aby zobaczyć pełną listę opcji i wartości dynamiczne.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Porządkuje pliki w dynamiczne drzewo katalogów zbudowane z MIME, dat,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'rozmiarów, wymiarów mediów, sum kontrolnych i tytułów metadanych.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'WAŻNE: remove/delete/trash/shred działają na obliczonej ŚCIEŻCE' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'DOCELOWEJ, nie na źródle. Źródło = cel jest odrzucane. Przejrzyj' ;;
				'preview output before using a destructive mode.') printf '%s' 'podgląd przed użyciem trybu destrukcyjnego.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Słowa kluczowe dla --dirs, --subdirs, --rename i --extension' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'nie rozróżniają wielkości liter. Nieznane słowa stają się nazwami dosłownymi.' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'Listy łączy się znakiem + lub , (np. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Data i czasy pliku:' ;;
				'File identity:') printf '%s' 'Tożsamość pliku:' ;;
				'Size and media dimensions:') printf '%s' 'Rozmiar i wymiary mediów:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Poziomy rozdzielczości używają większego wymiaru:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadane (wymaga exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Brakujące narzędzia są proponowane do instalacji przy pierwszym użyciu (init-system).' ;;
				'Modes') printf '%s' 'Tryby' ;;
				'Filtering and processing') printf '%s' 'Filtrowanie i przetwarzanie' ;;
				'Destination and naming') printf '%s' 'Cel i nazywanie' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadane' ;;
				'Archives') printf '%s' 'Archiwa' ;;
				'Output and safety') printf '%s' 'Wyjście i bezpieczeństwo' ;;
				'Dynamic values') printf '%s' 'Wartości dynamiczne' ;;
				'Examples') printf '%s' 'Przykłady' ;;
				'Summary') printf '%s' 'Podsumowanie' ;;
				'Unsupported mode: %s') printf '%s' 'Nieobsługiwany tryb: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Nieprawidłowa wartość --pause: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred wymaga shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Nie można utworzyć katalogu docelowego: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Nieznana opcja: %s (zignorowano)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Nieobsługiwany język: %s (zobacz --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'To nie plik ani katalog: %s' ;;
				'Files to treat: %s') printf '%s' 'Pliki do potraktowania: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Rozpakowywanie zbyt głębokie: %s' ;;
				'Archive test failed: %s') printf '%s' 'Test archiwum nie powiódł się: %s' ;;
				'Extract failed: %s') printf '%s' 'Rozpakowanie nie powiodło się: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> usuń archiwum' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Kosz wymaga trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Rozpakowano(%s) + do kosza: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Rozpakowano(%s) + zniszczono: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Rozpakowano(%s) + usunięto: %s' ;;
				'Trash failed: %s') printf '%s' 'Kosz nie powiódł się: %s' ;;
				'Shred failed: %s') printf '%s' 'Niszczenie nie powiodło się: %s' ;;
				'Delete failed: %s') printf '%s' 'Usuwanie nie powiodło się: %s' ;;
				'Not a regular file: %s') printf '%s' 'To nie jest zwykły plik: %s' ;;
				'No MIME type for: %s') printf '%s' 'Brak typu MIME dla: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Pominięto typ (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Nie można utworzyć nazwy dla: %s' ;;
				'Cannot create: %s') printf '%s' 'Nie można utworzyć: %s' ;;
				'Same place: %s') printf '%s' 'To samo miejsce: %s' ;;
				'Copy failed: %s') printf '%s' 'Kopiowanie nie powiodło się: %s' ;;
				'Move failed: %s') printf '%s' 'Przenoszenie nie powiodło się: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: nie znaleziono celu: %s' ;;
				'Removed: %s') printf '%s' 'Usunięto: %s' ;;
				'Remove failed: %s') printf '%s' 'Usuwanie nie powiodło się: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: nie znaleziono celu: %s' ;;
				'Trashed: %s') printf '%s' 'Do kosza: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: nie znaleziono celu: %s' ;;
				'Shredded: %s') printf '%s' 'Zniszczono: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadane usunięto: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Nie można usunąć metadanych: %s' ;;
				'Copied : %s') printf '%s' 'Skopiowano  : %s' ;;
				'Moved  : %s') printf '%s' 'Przeniesiono: %s' ;;
				'Removed: %s') printf '%s' 'Usunięto    : %s' ;;
				'Extracted: %s') printf '%s' 'Rozpakowano: %s' ;;
				'Preview: %s') printf '%s' 'Podgląd: %s' ;;
				'Skipped: %s') printf '%s' 'Pominięto: %s' ;;
				'Failed : %s') printf '%s' 'Nieudane    : %s' ;;
				'Nothing to treat.') printf '%s' 'Nic do potraktowania.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Porządkowanie %s plik(ów) - tryb: %s, wątki: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Oczekiwanie na zakończenie zadań w tle...' ;;
				'Finished.') printf '%s' 'Gotowe.' ;;
				'Terminated by user!') printf '%s' 'Przerwane przez użytkownika!' ;;
				'deps: missing: %s') printf '%s' 'deps: brakuje: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: proponowana instalacja: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: zainstalować teraz? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: nie zainstalowano (ustaw DEPS_YES=1, aby instalować bez pytania)' ;;
				'deps: skipped') printf '%s' 'deps: pominięto' ;;
				'deps: no supported package manager found') printf '%s' 'deps: nie znaleziono obsługiwanego menedżera pakietów' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: brak sposobu na uprawnienia root (uruchom jako root lub zainstaluj sudo)' ;;
				'Error: ') printf '%s' 'Błąd: ' ;;
				'Warning: ') printf '%s' 'Ostrzeżenie: ' ;;
				'unknown camera') printf '%s' 'nieznany aparat' ;;
				'unknown date') printf '%s' 'nieznana data' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Język interfejsu (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Wyświetl listę języków' ;;
				'Languages') printf '%s' 'Języki' ;;
				'Available languages (--lang=XX):') printf '%s' 'Dostępne języki (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(domyślnie)        Tylko podgląd - wypisuje źródło <=> cel' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Kopiuje każdy plik do jego uporządkowanej lokalizacji' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Przenosi każdy plik do jego uporządkowanej lokalizacji' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Usuwa plik na obliczonej ŚCIEŻCE DOCELOWEJ (TARGET)' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias dla --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Wysyła obliczony cel do kosza pulpitu' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Uruchamia shred -u -n 1 na obliczonym celu' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Długa postać jednego z trybów powyżej (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Tylko pliki, których typ MIME zawiera VALUE' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Przechodzi przez podane katalogi do pełnej głębokości' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Uwzględnia ukryte pliki i katalogi' ;;
				'--links            Include symbolic links') printf '%s' '--links            Uwzględnia dowiązania symboliczne' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Czeka po każdym pliku' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Rozmiar puli wątków (domyślnie: nproc, min. 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Katalog bazowy drzewa (domyślnie: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Główne składniki katalogów (domyślnie: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Składniki katalogów pod poziomem głównym' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Tworzy nazwę pliku (bez rozszerzenia)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Tworzy rozszerzenie (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Nazwa pliku z wbudowanych metadanych (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   data EXIF obrazu, tagi audio/wideo)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Nadpisuje istniejące cele, w przeciwnym razie unikalna nazwa ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Dodaje poziomy <Aparat>/<YYYY-MM-DD> dla obrazów' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Usuwa metadane EXIF/GPS z celów po copy/move' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Rozpakowuje archiwa do katalogu tymczasowego i porządkuje zawartość' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (samo archiwum jest usuwane po sukcesie;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred stosują ten los zamiast tego)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNazwa = główny katalog / pojedynczy plik wewnątrz archiwum' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Wymusza kolorowe wyjście (automatycznie wykrywane na tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias dla --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Szczegóły per plik wyłączone; tylko podsumowanie' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Szczegóły per plik włączone (domyślnie)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Wypisuje podsumowanie (domyślnie)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Dopisuje jedną linię na akcję do FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Pisze skrypt cofania (domyślnie: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Krótkie przypomnienie' ;;
				'--help             This help') printf '%s' '--help             Ta pomoc' ;;
				'--version          Print the version') printf '%s' '--version          Wypisuje wersję' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		nl)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' ontbreekt en de pakketnaam is onbekend' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - zelfstandige multithread bestandsorganisator' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'Gebruik: Sort.sh [opties] <bestand|map> ...' ;;
				'Common starts:') printf '%s' 'Veelgebruikte starts:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'Gebruik --help voor de volledige optielijst en dynamische waarden.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'Sorteert bestanden in een dynamische mappenboom opgebouwd uit MIME, datums,' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'groottes, media-afmetingen, checksums en metadata-titels.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'BELANGRIJK: remove/delete/trash/shred werken op het berekende DOEL-pad,' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'niet op de bron. Bron = doel wordt geweigerd. Bekijk de voorbeelduitvoer' ;;
				'preview output before using a destructive mode.') printf '%s' 'voordat u een destructieve modus gebruikt.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'Sleutelwoorden voor --dirs, --subdirs, --rename en --extension zijn' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'hoofdletterongevoelig. Onbekende woorden worden letterlijke namen. Lijsten' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'worden samengevoegd met + of , (bijv. --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'Datum en bestandstijden:' ;;
				'File identity:') printf '%s' 'Bestandsidentiteit:' ;;
				'Size and media dimensions:') printf '%s' 'Grootte en media-afmetingen:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'Resolutieniveaus gebruiken de grootste afmeting:' ;;
				'Metadata (needs exiftool):') printf '%s' 'Metadata (vereist exiftool):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'Ontbrekende hulpmiddelen worden bij eerste gebruik voorgesteld voor installatie (init-system).' ;;
				'Modes') printf '%s' 'Modi' ;;
				'Filtering and processing') printf '%s' 'Filteren en verwerken' ;;
				'Destination and naming') printf '%s' 'Doel en naamgeving' ;;
				'EXIF / metadata') printf '%s' 'EXIF / metadata' ;;
				'Archives') printf '%s' 'Archieven' ;;
				'Output and safety') printf '%s' 'Uitvoer en veiligheid' ;;
				'Dynamic values') printf '%s' 'Dynamische waarden' ;;
				'Examples') printf '%s' 'Voorbeelden' ;;
				'Summary') printf '%s' 'Samenvatting' ;;
				'Unsupported mode: %s') printf '%s' 'Niet-ondersteunde modus: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'Ongeldige --pause-waarde: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred vereist shred (coreutils)' ;;
				'Cannot create target directory: %s') printf '%s' 'Kan doelmap niet aanmaken: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'Onbekende optie: %s (genegeerd)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'Niet-ondersteunde taal: %s (zie --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'Geen bestand of map: %s' ;;
				'Files to treat: %s') printf '%s' 'Te behandelen bestanden: %s' ;;
				'Decompression too deep: %s') printf '%s' 'Uitpakken te diep: %s' ;;
				'Archive test failed: %s') printf '%s' 'Archieftest mislukt: %s' ;;
				'Extract failed: %s') printf '%s' 'Uitpakken mislukt: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> archief verwijderen' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'Prullenbak vereist trash-put (trash-cli)' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'Uitgepakt(%s) + prullenbak: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'Uitgepakt(%s) + versnipperd: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'Uitgepakt(%s) + verwijderd: %s' ;;
				'Trash failed: %s') printf '%s' 'Prullenbak mislukt: %s' ;;
				'Shred failed: %s') printf '%s' 'Versnipperen mislukt: %s' ;;
				'Delete failed: %s') printf '%s' 'Verwijderen mislukt: %s' ;;
				'Not a regular file: %s') printf '%s' 'Geen gewoon bestand: %s' ;;
				'No MIME type for: %s') printf '%s' 'Geen MIME-type voor: %s' ;;
				'Type skip (%s): %s') printf '%s' 'Type overgeslagen (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'Kan geen naam vormen voor: %s' ;;
				'Cannot create: %s') printf '%s' 'Kan niet aanmaken: %s' ;;
				'Same place: %s') printf '%s' 'Zelfde plek: %s' ;;
				'Copy failed: %s') printf '%s' 'Kopiëren mislukt: %s' ;;
				'Move failed: %s') printf '%s' 'Verplaatsen mislukt: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: doel niet gevonden: %s' ;;
				'Removed: %s') printf '%s' 'Verwijderd: %s' ;;
				'Remove failed: %s') printf '%s' 'Verwijderen mislukt: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: doel niet gevonden: %s' ;;
				'Trashed: %s') printf '%s' 'In de prullenbak: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: doel niet gevonden: %s' ;;
				'Shredded: %s') printf '%s' 'Versnipperd: %s' ;;
				'Stripped metadata: %s') printf '%s' 'Metadata verwijderd: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'Kon metadata niet verwijderen: %s' ;;
				'Copied : %s') printf '%s' 'Gekopieerd : %s' ;;
				'Moved  : %s') printf '%s' 'Verplaatst : %s' ;;
				'Removed: %s') printf '%s' 'Verwijderd : %s' ;;
				'Extracted: %s') printf '%s' 'Uitgepakt: %s' ;;
				'Preview: %s') printf '%s' 'Voorbeeld: %s' ;;
				'Skipped: %s') printf '%s' 'Overgeslagen: %s' ;;
				'Failed : %s') printf '%s' 'Mislukt  : %s' ;;
				'Nothing to treat.') printf '%s' 'Niets te behandelen.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'Sorteren van %s bestand(en) - modus: %s, threads: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'Wachten tot achtergrondtaken klaar zijn...' ;;
				'Finished.') printf '%s' 'Klaar.' ;;
				'Terminated by user!') printf '%s' 'Door gebruiker afgebroken!' ;;
				'deps: missing: %s') printf '%s' 'deps: ontbreekt: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: voorgestelde installatie: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: nu installeren? [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: niet geïnstalleerd (zet DEPS_YES=1 om zonder vragen te installeren)' ;;
				'deps: skipped') printf '%s' 'deps: overgeslagen' ;;
				'deps: no supported package manager found') printf '%s' 'deps: geen ondersteunde pakketbeheerder gevonden' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: geen manier om root te worden (draai als root of installeer sudo)' ;;
				'Error: ') printf '%s' 'Fout: ' ;;
				'Warning: ') printf '%s' 'Waarschuwing: ' ;;
				'unknown camera') printf '%s' 'onbekende camera' ;;
				'unknown date') printf '%s' 'onbekende datum' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          Interfacetaal (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             Toon de taallijst' ;;
				'Languages') printf '%s' 'Talen' ;;
				'Available languages (--lang=XX):') printf '%s' 'Beschikbare talen (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(standaard)        Alleen voorbeeld - print bron <=> doel' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             Kopieert elk bestand naar zijn gesorteerde locatie' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             Verplaatst elk bestand naar zijn gesorteerde locatie' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           Verwijdert het bestand op het berekende DOEL-pad' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           Alias voor --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            Stuurt het berekende doel naar de prullenbak' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            Voert shred -u -n 1 uit op het berekende doel' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       Lange vorm van een van de modi hierboven (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       Alleen bestanden waarvan het MIME-type VALUE bevat' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        Doorloopt opgegeven mappen tot volledige diepte' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           Omvat verborgen bestanden en mappen' ;;
				'--links            Include symbolic links') printf '%s' '--links            Omvat symbolische koppelingen' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    Wacht na elk bestand' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           Thread-poolgrootte (standaard: nproc, min. 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       Basismap van de gesorteerde boom (standaard: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        Primaire mapcomponenten (standaard: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     Mapcomponenten onder het primaire niveau' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     Genereert de bestandsnaam (zonder extensie)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  Genereert de extensie (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            Bestandsnaam uit ingebedde metadata (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   EXIF-datum van afbeelding, audio/video-tags)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          Overschrijft bestaande doelen, anders unieke ~(N)-naam' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             Voegt <Camera>/<YYYY-MM-DD>-niveaus toe voor afbeeldingen' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            Verwijdert EXIF/GPS-metadata van doelen na copy/move' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       Pakt archieven uit in een tijdelijke map en sorteert de inhoud' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (het archief zelf wordt na succes verwijderd;' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred passen dat lot in plaats daarvan toe)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedNaam = hoofdmap / enkel bestand in het archief' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          Forceert gekleurde uitvoer (automatisch gedetecteerd op een tty)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           Alias voor --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            Details per bestand uit; alleen samenvatting' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          Details per bestand aan (standaard)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            Print de samenvatting (standaard)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         Voegt één regel per actie toe aan FILE' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      Schrijft een undo-script (standaard: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            Korte herinnering' ;;
				'--help             This help') printf '%s' '--help             Deze hulp' ;;
				'--version          Print the version') printf '%s' '--version          Print de versie' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		fa)
			case "$1" in
				'deps: '\''%s'\'' is missing and its package name is unknown') printf '%s' 'deps: '\''%s'\'' غایب است و نام بسته آن نامعلوم است' ;;
				'Sort 19 - self-contained threaded organizer + magic detection') printf '%s' 'Sort 17.3 - سازمان‌دهنده چندنخستی خودکفا' ;;
				'Usage: Sort.sh [options] <file|directory> ...') printf '%s' 'استفاده: Sort.sh [گزینه‌ها] <فایل|پوشه> ...' ;;
				'Common starts:') printf '%s' 'شروع‌های رایج:' ;;
				'Use --help for the full option list and dynamic values.') printf '%s' 'برای فهرست کامل گزینه‌ها و مقادیر پویا از --help استفاده کنید.' ;;
				'Sorts files into a dynamic directory tree built from MIME, dates,') printf '%s' 'فایل‌ها را در درخت پوشه‌ای پویا ساخته‌شده از MIME، تاریخ‌ها،' ;;
				'sizes, media dimensions, checksums and metadata titles.') printf '%s' 'اندازه‌ها، ابعاد رسانه، چک‌سام‌ها و عنوان‌های فراداده مرتب می‌کند.' ;;
				'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET') printf '%s' 'مهم: remove/delete/trash/shred روی مسیر هدف (TARGET)' ;;
				'path, not on the source. Source = target is refused. Review the') printf '%s' 'محاسبه‌شده اثر می‌کنند، نه روی مبدأ. مبدأ = هدف رد می‌شود. پیش از' ;;
				'preview output before using a destructive mode.') printf '%s' 'استفاده از حالت مخرب، خروجی پیش‌نمایش را بررسی کنید.' ;;
				'Case-insensitive keywords for --dirs, --subdirs, --rename and') printf '%s' 'کلیدواژه‌های --dirs، --subdirs، --rename و --extension' ;;
				'--extension. Unknown words become literal names. Lists are joined') printf '%s' 'به بزرگی/کوچکی حروف حساس نیستند. واژه‌های ناشناخته نام تحت‌اللفظی می‌شوند. فهرست‌ها' ;;
				'with + or , (e.g. --dirs=year+month --subdirs=format,size).') printf '%s' 'با + یا , به هم می‌پیوندند (مثلاً --dirs=year+month --subdirs=format,size).' ;;
				'Date and file times:') printf '%s' 'تاریخ و زمان‌های فایل:' ;;
				'File identity:') printf '%s' 'هویت فایل:' ;;
				'Size and media dimensions:') printf '%s' 'اندازه و ابعاد رسانه:' ;;
				'Resolution tiers use the larger dimension:') printf '%s' 'سطوح وضوح از بُعد بزرگ‌تر استفاده می‌کنند:' ;;
				'Metadata (needs exiftool):') printf '%s' 'فراداده (exiftool لازم است):' ;;
				'Missing tools are proposed for install on first use (init-system).') printf '%s' 'ابزارهای غایب در نخستین استفاده برای نصب پیشنهاد می‌شوند (init-system).' ;;
				'Modes') printf '%s' 'حالت‌ها' ;;
				'Filtering and processing') printf '%s' 'پالایش و پردازش' ;;
				'Destination and naming') printf '%s' 'مقصد و نام‌گذاری' ;;
				'EXIF / metadata') printf '%s' 'EXIF / فراداده' ;;
				'Archives') printf '%s' 'آرشیوها' ;;
				'Output and safety') printf '%s' 'خروجی و ایمنی' ;;
				'Dynamic values') printf '%s' 'مقادیر پویا' ;;
				'Examples') printf '%s' 'نمونه‌ها' ;;
				'Summary') printf '%s' 'خلاصه' ;;
				'Unsupported mode: %s') printf '%s' 'حالت پشتیبانی‌نشده: %s' ;;
				'Invalid --pause value: %s') printf '%s' 'مقدار نامعتبر --pause: %s' ;;
				'--mode=shred requires shred (coreutils)') printf '%s' '--mode=shred به shred (coreutils) نیاز دارد' ;;
				'Cannot create target directory: %s') printf '%s' 'ساخت پوشه هدف ممکن نیست: %s' ;;
				'Unknown option: %s (ignored)') printf '%s' 'گزینه ناشناخته: %s (نادیده گرفته شد)' ;;
				'Unsupported language: %s (see --lang)') printf '%s' 'زبان پشتیبانی‌نشده: %s (ببینید --lang)' ;;
				'Not a file or directory: %s') printf '%s' 'فایل یا پوشه نیست: %s' ;;
				'Files to treat: %s') printf '%s' 'فایل‌های قابل پردازش: %s' ;;
				'Decompression too deep: %s') printf '%s' 'بازکردن آرشیو بیش از حد عمیق: %s' ;;
				'Archive test failed: %s') printf '%s' 'آزمون آرشیو ناموفق: %s' ;;
				'Extract failed: %s') printf '%s' 'بازکردن ناموفق: %s' ;;
				'EXTRACT(%s): %s <=> delete archive') printf '%s' 'EXTRACT(%s): %s <=> حذف آرشیو' ;;
				'Trash needs trash-put (trash-cli)') printf '%s' 'زباله‌دان به trash-put (trash-cli) نیاز دارد' ;;
				'Extracted(%s) + trashed: %s') printf '%s' 'باز شد(%s) + زباله‌دان: %s' ;;
				'Extracted(%s) + shredded: %s') printf '%s' 'باز شد(%s) + نابود شد: %s' ;;
				'Extracted(%s) + deleted: %s') printf '%s' 'باز شد(%s) + حذف شد: %s' ;;
				'Trash failed: %s') printf '%s' 'زباله‌دان ناموفق: %s' ;;
				'Shred failed: %s') printf '%s' 'نابودی ناموفق: %s' ;;
				'Delete failed: %s') printf '%s' 'حذف ناموفق: %s' ;;
				'Not a regular file: %s') printf '%s' 'فایل عادی نیست: %s' ;;
				'No MIME type for: %s') printf '%s' 'هیچ نوع MIME برای: %s' ;;
				'Type skip (%s): %s') printf '%s' 'نوع رد شد (%s): %s' ;;
				'EXIF: %s %s') printf '%s' 'EXIF: %s %s' ;;
				'Cannot build a name for: %s') printf '%s' 'ساخت نام ممکن نیست برای: %s' ;;
				'Cannot create: %s') printf '%s' 'ساخت ممکن نیست: %s' ;;
				'Same place: %s') printf '%s' 'همان جا: %s' ;;
				'Copy failed: %s') printf '%s' 'رونوشت ناموفق: %s' ;;
				'Move failed: %s') printf '%s' 'جابه‌جایی ناموفق: %s' ;;
				'Remove: target not found: %s') printf '%s' 'Remove: هدف یافت نشد: %s' ;;
				'Removed: %s') printf '%s' 'حذف شد: %s' ;;
				'Remove failed: %s') printf '%s' 'حذف ناموفق: %s' ;;
				'Trash: target not found: %s') printf '%s' 'Trash: هدف یافت نشد: %s' ;;
				'Trashed: %s') printf '%s' 'زباله‌دان: %s' ;;
				'Shred: target not found: %s') printf '%s' 'Shred: هدف یافت نشد: %s' ;;
				'Shredded: %s') printf '%s' 'نابود شد: %s' ;;
				'Stripped metadata: %s') printf '%s' 'فراداده حذف شد: %s' ;;
				'Could not strip metadata: %s') printf '%s' 'حذف فراداده ممکن نشد: %s' ;;
				'Copied : %s') printf '%s' 'رونوشت : %s' ;;
				'Moved  : %s') printf '%s' 'جابه‌جا : %s' ;;
				'Removed: %s') printf '%s' 'حذف شد : %s' ;;
				'Extracted: %s') printf '%s' 'باز شد: %s' ;;
				'Preview: %s') printf '%s' 'پیش‌نمایش: %s' ;;
				'Skipped: %s') printf '%s' 'رد شد : %s' ;;
				'Failed : %s') printf '%s' 'ناموفق : %s' ;;
				'Nothing to treat.') printf '%s' 'چیزی برای پردازش نیست.' ;;
				'Sorting %s file(s) - mode: %s, jobs: %s') printf '%s' 'مرتب‌سازی %s فایل - حالت: %s، نخ‌ها: %s' ;;
				'Waiting for background jobs to finish...') printf '%s' 'در انتظار پایان کارهای پس‌زمینه...' ;;
				'Finished.') printf '%s' 'تمام شد.' ;;
				'Terminated by user!') printf '%s' 'توسط کاربر متوقف شد!' ;;
				'deps: missing: %s') printf '%s' 'deps: غایب: %s' ;;
				'deps: proposed install: %s') printf '%s' 'deps: نصب پیشنهادی: %s' ;;
				'deps: install now? [y/N] ') printf '%s' 'deps: الان نصب شود؟ [y/N] ' ;;
				'deps: not installed (set DEPS_YES=1 to install without asking)') printf '%s' 'deps: نصب نشد (برای نصب بدون پرسش DEPS_YES=1 بگذارید)' ;;
				'deps: skipped') printf '%s' 'deps: رد شد' ;;
				'deps: no supported package manager found') printf '%s' 'deps: هیچ مدیر بسته پشتیبانی‌شده‌ای یافت نشد' ;;
				'deps: no way to gain root (run as root or install sudo)') printf '%s' 'deps: راهی برای دسترسی root نیست (به‌عنوان root اجرا کنید یا sudo نصب کنید)' ;;
				'Error: ') printf '%s' 'خطا: ' ;;
				'Warning: ') printf '%s' 'هشدار: ' ;;
				'unknown camera') printf '%s' 'دوربین نامعلوم' ;;
				'unknown date') printf '%s' 'تاریخ نامعلوم' ;;
				'--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)') printf '%s' '--lang=XX          زبان رابط کاربری (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' ;;
				'--lang             Print the language list') printf '%s' '--lang             چاپ فهرست زبان‌ها' ;;
				'Languages') printf '%s' 'زبان‌ها' ;;
				'Available languages (--lang=XX):') printf '%s' 'زبان‌های موجود (--lang=XX):' ;;
				'(default)          Preview only - print source <=> target') printf '%s' '(پیش‌فرض)          فقط پیش‌نمایش - چاپ مبدأ <=> هدف' ;;
				'--copy             Copy every file to its sorted location') printf '%s' '--copy             هر فایل را به جای مرتب‌شده‌اش رونوشت می‌کند' ;;
				'--move             Move every file to its sorted location') printf '%s' '--move             هر فایل را به جای مرتب‌شده‌اش جابه‌جا می‌کند' ;;
				'--remove           Remove the file at the calculated TARGET path') printf '%s' '--remove           فایل را در مسیر هدف (TARGET) محاسبه‌شده حذف می‌کند' ;;
				'--delete           Alias for --remove') printf '%s' '--delete           مترادف --remove' ;;
				'--trash            Send the calculated target to the desktop trash') printf '%s' '--trash            هدف محاسبه‌شده را به زباله‌دان می‌فرستد' ;;
				'--shred            Run shred -u -n 1 on the calculated target') printf '%s' '--shred            روی هدف محاسبه‌شده shred -u -n 1 اجرا می‌کند' ;;
				'--mode=VALUE       Long form of any mode above (copy/move/...)') printf '%s' '--mode=VALUE       شکل بلند یکی از حالت‌های بالا (copy/move/...)' ;;
				'--type=VALUE       Only files whose MIME type contains VALUE') printf '%s' '--type=VALUE       فقط فایل‌هایی که نوع MIME شامل VALUE باشد' ;;
				'                   (image, video, audio, pdf, application, ...)') printf '%s' '                   (image, video, audio, pdf, application, ...)' ;;
				'--recursive        Walk supplied directories to full depth') printf '%s' '--recursive        پوشه‌های داده‌شده را تا عمق کامل می‌پیماید' ;;
				'--hidden           Include hidden files and directories') printf '%s' '--hidden           فایل‌ها و پوشه‌های پنهان را شامل می‌شود' ;;
				'--links            Include symbolic links') printf '%s' '--links            پیوندهای نمادین را شامل می‌شود' ;;
				'--pause=SECONDS    Wait after each file') printf '%s' '--pause=SECONDS    بعد از هر فایل منتظر می‌ماند' ;;
				'--jobs=N           Thread pool size (default: nproc, min 1)') printf '%s' '--jobs=N           اندازه استخر نخ‌ها (پیش‌فرض: nproc، حداقل 1)' ;;
				'--target=DIR       Base directory of the sorted tree (default: .)') printf '%s' '--target=DIR       پوشه پایه درخت مرتب (پیش‌فرض: .)' ;;
				'--dirs=LIST        Primary directory components (default: mime)') printf '%s' '--dirs=LIST        مؤلفه‌های پوشه اصلی (پیش‌فرض: mime)' ;;
				'--subdirs=LIST     Directory components beneath the primary') printf '%s' '--subdirs=LIST     مؤلفه‌های پوشه زیر سطح اصلی' ;;
				'--rename=VALUE     Generate the filename (without extension)') printf '%s' '--rename=VALUE     نام فایل را می‌سازد (بدون پسوند)' ;;
				'--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)') printf '%s' '--extension=VALUE  پسوند را می‌سازد (none/mime/mime-sub/mime-ext/...)' ;;
				'--title            Filename from embedded metadata (PDF /Title,') printf '%s' '--title            نام فایل از فراداده درون‌سازی‌شده (PDF /Title,' ;;
				'                   image EXIF date, audio/video tags)') printf '%s' '                   تاریخ EXIF تصویر، برچسب‌های صوتی/ویدیویی)' ;;
				'--replace          Overwrite existing targets, else unique ~(N) name') printf '%s' '--replace          روی اهداف موجود می‌نویسد، وگرنه نام یکتای ~(N)' ;;
				'--exif             Add <Camera>/<YYYY-MM-DD> levels for images') printf '%s' '--exif             برای تصاویر سطح‌های <دوربین>/<YYYY-MM-DD> می‌افزاید' ;;
				'--strip            Strip EXIF/GPS metadata from targets after copy/move') printf '%s' '--strip            بعد از copy/move فراداده EXIF/GPS را از اهداف حذف می‌کند' ;;
				'--decompress       Extract archives to a temp dir and sort the contents') printf '%s' '--decompress       آرشیوها را در پوشه موقت باز و محتوایشان را مرتب می‌کند' ;;
				'                   (the archive itself is deleted after success;') printf '%s' '                   (خود آرشیو پس از موفقیت حذف می‌شود؛' ;;
				'                   --trash / --shred apply that fate to it instead)') printf '%s' '                   --trash / --shred به‌جای آن سرنوشت مذکور را اعمال می‌کنند)' ;;
				'--rename=compressedName = main dir / single file inside the archive') printf '%s' '--rename=compressedنام = پوشه اصلی / تک‌فایل درون آرشیو' ;;
				'--colored          Force colored output (auto-detected on a tty)') printf '%s' '--colored          خروجی رنگی را اجباری می‌کند (روی tty خودکار تشخیص داده می‌شود)' ;;
				'--colors           Alias for --colored') printf '%s' '--colors           مترادف --colored' ;;
				'--quiet            Per-file details off; summary only') printf '%s' '--quiet            جزئیات هر فایل خاموش؛ فقط خلاصه' ;;
				'--verbose          Per-file details on (default)') printf '%s' '--verbose          جزئیات هر فایل روشن (پیش‌فرض)' ;;
				'--stats            Print the summary (default)') printf '%s' '--stats            خلاصه را چاپ می‌کند (پیش‌فرض)' ;;
				'--log=FILE         Append one line per action to FILE') printf '%s' '--log=FILE         هر عمل یک خط به FILE می‌افزاید' ;;
				'--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)') printf '%s' '--undo[=FILE]      اسکریپت بازگردانی می‌نویسد (پیش‌فرض: sort_undo_<time>.sh)' ;;
				'--usage            Short reminder') printf '%s' '--usage            یادآوری کوتاه' ;;
				'--help             This help') printf '%s' '--help             این راهنما' ;;
				'--version          Print the version') printf '%s' '--version          نسخه را چاپ می‌کند' ;;
				*) printf '%s' "$1" ;;
			esac
			;;
		*)
			printf '%s' "$1" ;;
	esac
}

# Tf: translate a %s template, then substitute the remaining arguments.
Tf() {
	local Tpl
	Tpl=$(T "$1")
	shift
	printf "$Tpl" "$@"
}

# Lang_Name: native name of a language code.
Lang_Name() {
	case "$1" in
		en) printf '%s' 'English' ;;
		zh) printf '%s' 'Chinese (Mandarin) / 中文' ;;
		hi) printf '%s' 'Hindi / हिन्दी' ;;
		es) printf '%s' 'Spanish / Español' ;;
		fr) printf '%s' 'French / Français' ;;
		ar) printf '%s' 'Arabic / العربية' ;;
		bn) printf '%s' 'Bengali / বাংলা' ;;
		pt) printf '%s' 'Portuguese / Português' ;;
		ru) printf '%s' 'Russian / Русский' ;;
		ur) printf '%s' 'Urdu / اردو' ;;
		id) printf '%s' 'Indonesian / Bahasa Indonesia' ;;
		de) printf '%s' 'German / Deutsch' ;;
		ja) printf '%s' 'Japanese / 日本語' ;;
		tr) printf '%s' 'Turkish / Türkçe' ;;
		ko) printf '%s' 'Korean / 한국어' ;;
		vi) printf '%s' 'Vietnamese / Tiếng Việt' ;;
		it) printf '%s' 'Italian / Italiano' ;;
		pl) printf '%s' 'Polish / Polski' ;;
		nl) printf '%s' 'Dutch / Nederlands' ;;
		fa) printf '%s' 'Persian / فارسی' ;;
		*) printf '%s' "$1" ;;
	esac
}

# Lang_List: print the available UI languages.
Lang_List() {
	local Code
	printf '%s\n' "$(T 'Available languages (--lang=XX):')"
	for Code in $LANG_CODES; do
		printf '  %s — %s\n' "$Code" "$(Lang_Name "$Code")"
	done
}


Usage() {
	Print_Header "$(T 'Sort 19 - self-contained threaded organizer + magic detection')"
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
	Print_Header "$(T 'Sort 19 - self-contained threaded organizer + magic detection')"
	Print_Message 'Sorts files into a dynamic directory tree built from MIME, dates,'
	Print_Message 'sizes, media dimensions, checksums and metadata titles.'
	printf '\n'
	Print_Header "$(T 'Modes')" '='
	printf '\t%s\n' "$(T '(default)          Preview only - print source <=> target')"
	printf '\t%s\n' "$(T '--copy             Copy every file to its sorted location')"
	printf '\t%s\n' "$(T '--move             Move every file to its sorted location')"
	printf '\t%s\n' "$(T '--remove           Remove the file at the calculated TARGET path')"
	printf '\t%s\n' "$(T '--delete           Alias for --remove')"
	printf '\t%s\n' "$(T '--trash            Send the calculated target to the desktop trash')"
	printf '\t%s\n' "$(T '--magic            Print a magic-number detection report (237 signature formats) and exit')"
	printf '\t%s\n' "$(T '--shred            Run shred -u -n 1 on the calculated target')"
	printf '\t%s\n' "$(T '--mode=VALUE       Long form of any mode above (copy/move/...)')"
	printf '\n'
	Print_Message 'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET'
	Print_Message 'path, not on the source. Source = target is refused. Review the'
	Print_Message 'preview output before using a destructive mode.'
	printf '\n'
	Print_Header "$(T 'Filtering and processing')" '='
	printf '\t%s\n' "$(T '--type=VALUE       Only files whose MIME type contains VALUE')"
	printf '\t%s\n' "$(T '                   (image, video, audio, pdf, application, ...)')"
	printf '\t%s\n' "$(T '--recursive        Walk supplied directories to full depth')"
	printf '\t%s\n' "$(T '--hidden           Include hidden files and directories')"
	printf '\t%s\n' "$(T '--links            Include symbolic links')"
	printf '\t%s\n' "$(T '--pause=SECONDS    Wait after each file')"
	printf '\t%s\n' "$(T '--jobs=N           Thread pool size (default: nproc, min 1)')"
	printf '\n'
	Print_Header "$(T 'Destination and naming')" '='
	printf '\t%s\n' "$(T '--target=DIR       Base directory of the sorted tree (default: .)')"
	printf '\t%s\n' "$(T '--dirs=LIST        Primary directory components (default: mime)')"
	printf '\t%s\n' "$(T '--subdirs=LIST     Directory components beneath the primary')"
	printf '\t%s\n' "$(T '--rename=VALUE     Generate the filename (without extension)')"
	printf '\t%s\n' "$(T '--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)')"
	printf '\t%s\n' "$(T '--extension=lower/upper  Case of the original extension')"
	printf '\t%s\n' "$(T '--extension=mime-main    Extension from the MIME main type')"
	printf '\t%s\n' "$(T '--extension=id3-genre    Extension from an audio tag (any id3-* keyword)')"
	printf '\t%s\n' "$(T '--title            Filename from embedded metadata (PDF /Title,')"
	printf '\t%s\n' "$(T '                   image EXIF date, audio/video tags)')"
	printf '\t%s\n' "$(T '--replace          Overwrite existing targets, else unique ~(N) name')"
	printf '\n'
	Print_Header "$(T 'EXIF / metadata')" '='
	printf '\t%s\n' "$(T '--exif             Add <Camera>/<YYYY-MM-DD> levels for images')"
	printf '\t%s\n' "$(T '--strip            Strip EXIF/GPS metadata from targets after copy/move')"
	printf '\n'
	Print_Header "$(T 'Archives')" '='
	printf '\t%s\n' "$(T '--decompress       Extract archives to a temp dir and sort the contents')"
	printf '\t%s\n' "$(T '                   (the archive itself is deleted after success;')"
	printf '\t%s\n' "$(T '                   --trash / --shred apply that fate to it instead)')"
	printf '\t%s\n' '--rename=compressed  Name = main dir / single file inside the archive'
	printf '\n'
	Print_Header "$(T 'Output and safety')" '='
	printf '\t%s\n' "$(T '--colored          Force colored output (auto-detected on a tty)')"
	printf '\t%s\n' "$(T '--colors           Alias for --colored')"
	printf '\t%s\n' "$(T '--quiet            Per-file details off; summary only')"
	printf '\t%s\n' "$(T '--verbose          Per-file details on (default)')"
	printf '\t%s\n' "$(T '--stats            Print the summary (default)')"
	printf '\t%s\n' "$(T '--log=FILE         Append one line per action to FILE')"
	printf '\t%s\n' "$(T '--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)')"
	printf '\t%s\n' "$(T '--usage            Short reminder')"
	printf '\t%s\n' "$(T '--help             This help')"
	printf '\t%s\n' "$(T '--version          Print the version')"
	printf '\t%s\n' "$(T '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)')"
	printf '\t%s\n' "$(T '--lang             Print the language list')"
	printf '\n'
	Print_Header "$(T 'Dynamic values')" '='
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
	Print_Message 'Audio tags - ID3v1/ID3v2 read in pure bash, exiftool fallback:'
	printf '\t%s\n' 'id3 / audio   <Artist>/<Year - Album> composite directory'
	printf '\t%s\n' 'id3-title id3-artist id3-album id3-year id3-genre id3-track'
	printf '\t%s\n' 'also usable in --rename and --extension, e.g. --rename=id3-artist'
	printf '\n'
	Print_Header "$(T 'Examples')" '='
	printf '\t%s\n' 'Sort.sh --dirs=mime-main --type=image ./Downloads/*'
	printf '\t%s\n' 'Sort.sh --mode=move --dirs=year+month --title --type=video ~/V'
	printf '\t%s\n' 'Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg'
	printf '\t%s\n' 'Sort.sh --mode=trash --recursive --type=audio --pause=1 ~/Music'
	printf '\t%s\n' 'Sort.sh --mode=move --dirs=id3 --rename=id3-track --extension=lower ~/Music'
	printf '\t%s\n' 'Sort.sh --mode=copy --subdirs=id3-artist,id3-album --type=audio ~/Music'
	printf '\n'
	printf '\n'
	Print_Header "$(T 'Languages')" '='
	Lang_List
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
		--magic)
			Magic_Mode=1
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
			printf 'Sort 19\n'
			exit 0
			;;
		--lang=*)
			Lang=${Item#--lang=}
			Lang=${Lang,,}
			;;
		--lang)
			Lang_List
			exit 0
			;;
		--)
			shift
			;;
		-*)
			Print_Warning "$(Tf 'Unknown option: %s (ignored)' "$Item")"
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
	case " $LANG_CODES " in
	*" $Lang "*)
		;;
	*)
		Print_Error "$(Tf 'Unsupported language: %s (see --lang)' "$Lang")"
		Lang_List >&2
		return 1
		;;
	esac

	case "$Modus" in
	Print | Copy | Move | Remove | Trash | Shred) ;;
	*)
		Print_Error "$(Tf 'Unsupported mode: %s' "$Modus")"
		return 1
		;;
	esac

	if [ -n "$Pause" ] && ! [[ "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		Print_Error "$(Tf 'Invalid --pause value: %s' "$Pause")"
		return 1
	fi

	if [ "$Modus" = 'Shred' ] && ! command -v shred >/dev/null; then
		Print_Error '--mode=shred requires shred (coreutils)'
		return 1
	fi

	mkdir -p -- "$Target_Dir" || {
		Print_Error "$(Tf 'Cannot create target directory: %s' "$Target_Dir")"
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
			Print_Warning "$(Tf 'Not a file or directory: %s' "$Item")"
		fi
	done

	[ "$Quiet" -eq 1 ] || Print_Info "$(Tf 'Files to treat: %s' "${#Targets[@]}")"
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
# Size class name from a byte count - shared core for the size segments.
# Size_Unit_From_Bytes <bytes>
Size_Unit_From_Bytes() {
	local Size=$1

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

# Size class name of a file (Byte / Kilo / Mega / Giga / Tera).
# Size_Unit_Name <file>
Size_Unit_Name() {
	local Size

	Size=$(Get_File_Size "$1") || return 1
	Size_Unit_From_Bytes "$Size"
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
		A=$(Get_Audio_Artist "$File" 2>/dev/null)
		Al=$(Get_Audio_Album "$File" 2>/dev/null)
		T=$(Get_Audio_Title "$File" 2>/dev/null)
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
# Cached file timestamps - ONE stat call per file returns birth and mtime.
# Get_File_Timestamps <file>  ->  "<birth>|<mtime>"
Get_File_Timestamps() {
	local Ts

	Ts=${Sort_Stat_Cache[$1]-}
	if [ -z "$Ts" ]; then
		Ts=$(stat -c '%w|%y' -- "$1" 2>/dev/null)
		Sort_Stat_Cache[$1]=$Ts
	fi
	printf '%s' "$Ts"
}

# Cached date formatting - one date fork per <file,format> pair.
# Get_Cached_Date <file> <timestamp> <format> <fallback>
Get_Cached_Date() {
	local Key="$1|$3" Out

	Out=${Sort_Date_Cache[$Key]-}
	if [ -z "$Out" ]; then
		Out=$(date -d "${2%%.*}" "$3" 2>/dev/null) || Out=$4
		Sort_Date_Cache[$Key]=$Out
	fi
	printf '%s' "$Out"
}

Resolve_Segment() {
	local Key=${1,,} File=$2 Mime=$3 Main=$4
	local Ts T TsB TsM WxH N Out Folder

	case "$Key" in
	# Date and file times
	year | month | day | year+month | year+month+day)
		Ts=$(Get_File_Timestamps "$File")
		TsB=${Ts%%|*}
		TsM=${Ts#*|}
		[[ -z "$TsB" || "$TsB" == '-'* ]] && Ts=$TsM || Ts=$TsB
		case "$Key" in
		year)
			Get_Cached_Date "$File" "$Ts" +%Y '0000'
			;;
		month)
			Get_Cached_Date "$File" "$Ts" +%m '00'
			;;
		day)
			Get_Cached_Date "$File" "$Ts" +%d '00'
			;;
		year+month)
			Get_Cached_Date "$File" "$Ts" +%Y/%m '0000/00'
			;;
		year+month+day)
			Get_Cached_Date "$File" "$Ts" +%Y/%m/%d '0000/00/00'
			;;
		esac
		;;
	created)
		Ts=$(Get_File_Timestamps "$File")
		printf '%s' "${Ts%%|*}" | sed 's/\..*//; s/ /_/'
		;;
	modified)
		Ts=$(Get_File_Timestamps "$File")
		printf '%s' "${Ts#*|}" | sed 's/\..*//; s/ /_/'
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

	# Audio tags (ID3v1 / ID3v2, exiftool fallback)
	id3 | audio)
		Get_Audio_Tags_Dir "$File"
		;;
	id3-title | id3-artist | id3-album | id3-year | id3-genre | id3-track)
		Sanitize_Name "$(Id3_Field "$File" "${Key#id3-}")"
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
	mime-main)
		printf '.%s' "${Mime%%/*}"
		;;
	lower)
		Ext=$(Get_Compound_Ext "$File") || Ext=$(Get_File_Ext "$File")
		[ -n "$Ext" ] && printf '.%s' "${Ext,,}"
		;;
	upper)
		Ext=$(Get_Compound_Ext "$File") || Ext=$(Get_File_Ext "$File")
		[ -n "$Ext" ] && printf '.%s' "${Ext^^}"
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
		printf '# Sort 17.3 log started at %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LogFile"
	fi
	if [ -n "$UndoFile" ]; then
		{
			printf '#!/usr/bin/env bash\n'
			printf '# Undo script generated by Sort 17.3 at %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
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
		[ "$Quiet" -eq 1 ] || Print_Info "$(Tf 'Stripped metadata: %s' "$Target")"
	else
		rm -f -- "$Tmp"
		Print_Warning "$(Tf 'Could not strip metadata: %s' "$Target")"
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
# HH-MM-SS tag from a seconds value - shared core for the duration segments.
# Duration_Tag_From_Seconds <seconds>
Duration_Tag_From_Seconds() {
	local Seconds=${1%.*}
	Seconds=${Seconds:-0}
	local H=$((Seconds / 3600))
	local M=$(((Seconds % 3600) / 60))
	local S=$((Seconds % 60))

	printf '%02d-%02d-%02d' "$H" "$M" "$S"
}

# EXIF-style duration tag of a video, empty when unusable.
# Video_Duration_Tag <file>
Video_Duration_Tag() {
	local Seconds

	Seconds=$(Get_Duration "$1") || return 1
	Duration_Tag_From_Seconds "$Seconds"
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
		Print_Error "$(Tf 'Decompression too deep: %s' "$File")"
		return 1
	}

	# Extract + test: a failing archive is never touched further
	Archive_Test "$File" || {
		Print_Error "$(Tf 'Archive test failed: %s' "$File")"
		return 1
	}

	Tmp=$(mktemp -d) || return 1
	Archive_Extract "$File" "$Tmp" || {
		Print_Error "$(Tf 'Extract failed: %s' "$File")"
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
		Print_Message "$(Tf 'EXTRACT(%s): %s <=> delete archive' "$Count" "$File")"
		;;
	Trash)
		Deps_Ensure trash-put || {
			Status='FAILED'
			Print_Error 'Trash needs trash-put (trash-cli)'
			return 1
		}
		if trash-put -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "$(Tf 'Extracted(%s) + trashed: %s' "$Count" "$File")"
			Log_Action "TRASH $File"
		else
			Status='FAILED'
			Print_Error "$(Tf 'Trash failed: %s' "$File")"
			return 1
		fi
		;;
	Shred)
		if shred -u -n 1 -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "$(Tf 'Extracted(%s) + shredded: %s' "$Count" "$File")"
			Log_Action "SHRED $File"
		else
			Status='FAILED'
			Print_Error "$(Tf 'Shred failed: %s' "$File")"
			return 1
		fi
		;;
	*)
		if rm -v -- "$File"; then
			Status='EXTRACTED'
			Print_Ok "$(Tf 'Extracted(%s) + deleted: %s' "$Count" "$File")"
			Log_Action "DELETE $File"
		else
			Status='FAILED'
			Print_Error "$(Tf 'Delete failed: %s' "$File")"
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
		Print_Error "$(Tf 'Not a regular file: %s' "$File")"
		return 1
	}

	# MIME type drives everything; no type -> no destination
	Mime=$(Get_MIME_Type "$File") || {
		Print_Error "$(Tf 'No MIME type for: %s' "$File")"
		return 1
	}
	Main=${Mime%%/*}

	# --type filter: the value must occur in the MIME type
	if [ -n "$Type_Filter" ] && [[ "${Mime,,}" != *"${Type_Filter,,}"* ]]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "$(Tf 'Type skip (%s): %s' "$Mime" "$File")"
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
					Print_Info "$(Tf 'EXIF: %s %s' "${Cam:-$(T 'unknown camera')}" "${DateDir:-$(T 'unknown date')}")"
				fi
			fi
			;;
		video)
			local Info WxH Dur

			# ONE ffprobe call for both dimensions and duration
			Info=$(Get_Media_Info "$File")
			WxH=${Info%%|*}
			Dur=${Info#*|}
			SubPart="${WxH:-unknown}/${Dur:-unknown}"
			;;
		*)
			local Size Unit

			# ONE stat call for both the size class and the human size
			Size=$(Get_File_Size "$File") || Size=0
			Unit=$(Size_Unit_From_Bytes "$Size")
			[ "$Unit" = 'Byte' ] || Unit="${Unit}Byte"
			SubPart="$Unit/$(Human_From_Bytes "$Size")"
			;;
		esac
	fi

	NewDir="${Target_Dir#./}/${DirPart:+$DirPart/}$SubPart"
	NewDir=${NewDir#./}

	# New name and extension
	Name=$(Build_Name "$File" "$Mime" "$Main") || {
		Print_Error "$(Tf 'Cannot build a name for: %s' "$File")"
		return 1
	}
	Ext=$(Build_Extension "$File" "$Mime")

	# Only Copy/Move need the target tree - preview stays side-effect free
	case "$Modus" in
	Copy | Move)
		mkdir -p -- "$NewDir" || {
			Print_Error "$(Tf 'Cannot create: %s' "$NewDir")"
			return 1
		}
		;;
	esac
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
		[ "$Quiet" -eq 1 ] || Print_Info "$(Tf 'Same place: %s' "$File")"
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
			Print_Error "$(Tf 'Copy failed: %s' "$File")"
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
			Print_Error "$(Tf 'Move failed: %s' "$File")"
			return 1
		fi
		;;
	Remove)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "$(Tf 'Remove: target not found: %s' "$New")"
			return 1
		fi
		if rm -v -- "$New"; then
			Status='REMOVED'
			Print_Ok "$(Tf 'Removed: %s' "$New")"
			Log_Action "REMOVE $New"
		else
			Print_Error "$(Tf 'Remove failed: %s' "$New")"
			return 1
		fi
		;;
	Trash)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "$(Tf 'Trash: target not found: %s' "$New")"
			return 1
		fi
		Deps_Ensure trash-put || {
			Print_Error 'Trash needs trash-put (trash-cli)'
			return 1
		}
		if trash-put -- "$New"; then
			Status='TRASHED'
			Print_Ok "$(Tf 'Trashed: %s' "$New")"
			Log_Action "TRASH $New"
		else
			Print_Error "$(Tf 'Trash failed: %s' "$New")"
			return 1
		fi
		;;
	Shred)
		if [ ! -e "$New" ]; then
			Status='FAILED'
			Print_Warning "$(Tf 'Shred: target not found: %s' "$New")"
			return 1
		fi
		if shred -u -n 1 -- "$New"; then
			Status='SHREDDED'
			Print_Ok "$(Tf 'Shredded: %s' "$New")"
			Log_Action "SHRED $New"
		else
			Print_Error "$(Tf 'Shred failed: %s' "$New")"
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
	local -i Running=0
	local -i Done_Copied=0 Done_Moved=0 Done_Preview=0 Done_Skipped=0 Done_Failed=0 Done_Other=0 Done_Extracted=0

	Tmp=$(mktemp -d) || return 1

	# Launch every file, keeping at most Max_Jobs running at once.
	# A bash counter tracks the pool - no jobs|wc forks per submission.
	while [ "$Idx" -lt "$Total" ]; do
		while [ "$Running" -ge "$Max_Jobs" ]; do
			wait -n || true
			Running=$((Running - 1))
		done

		(
			Process_File "${@:$((Idx + 1)):1}"
			printf '%s\n' "$Status" >"$Tmp/tag.$Idx"
		) >"$Tmp/out.$Idx" 2>&1 &

		Running=$((Running + 1))
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
	Print_Header "$(T 'Summary')"
	Print_Message "$(Tf 'Copied : %s' "$Done_Copied")"
	Print_Message "$(Tf 'Moved  : %s' "$Done_Moved")"
	Print_Message "$(Tf 'Removed: %s' "$Done_Other")"
	Print_Message "$(Tf 'Extracted: %s' "$Done_Extracted")"
	Print_Message "$(Tf 'Preview: %s' "$Done_Preview")"
	Print_Message "$(Tf 'Skipped: %s' "$Done_Skipped")"
	[ "$Done_Failed" -eq 0 ] && Print_Ok "$(Tf 'Failed : %s' "$Done_Failed")" || Print_Error "$(Tf 'Failed : %s' "$Done_Failed")"

	[ "$Done_Failed" -eq 0 ]
}

# ===========================================================================
# ===========================================================================
# ===========================================================================
# ===========================================================================
# ===========================================================================
# ===========================================================================
# MAGIC MODULE (V17.5) - --magic: magic-number detection report
# One associative array keyed by MIME type/subtype. Value fields:
#   Name|extensions|hex-pattern[|byte-offset]
# '?' in a pattern matches any nibble; the main MIME type is the key
# part before the '/'. Detection scores every matching key (concrete
# nibbles first, then pattern length) and reports the most specific
# hit. Pure bash + od. Zero external calls.
# ===========================================================================

declare -A Magic=(
	['application/x-virtualbox-vdi']='VirtualBox VDI disk|vdi|3c3c3c3c204f7261636c6520564d2056|64'
	['application/x-linux-swap']='Linux swap area|img|535741505350414345|4086'
	['application/x-mobipocket-ebook']='MOBI e-book|mobi,prc|424f4f4b4d4f4249|60'
	['application/x-ntfs-filesystem']='NTFS filesystem|img|4e54465320202020|3'
	['application/x-btrfs-filesystem']='Btrfs filesystem|img|5f42485266535f4d|64'
	['application/x-iso9660-image']='ISO 9660 image|iso,img|4344303031|32769'
	['application/x-tar']='TAR archive|tar|7573746172|257'
	['application/x-lzh']='LHA/LZH archive|lzh,lha|2d6c683?2d|1'
	['audio/s3m']='S3M module|s3m|5343524d|44'
	['audio/x-mod-mk']='Amiga MOD module|mod|4d214b21|108'
	['audio/x-mod-flt4']='Amiga MOD module|mod|46545434|108'
	['audio/x-mod-flt8']='Amiga MOD module|mod|46545438|108'
	['audio/x-mod-4chn']='Amiga MOD module|mod|3443484e|108'
	['audio/x-mod-6chn']='Amiga MOD module|mod|3643484e|108'
	['audio/x-mod-8chn']='Amiga MOD module|mod|3843484e|108'
	['application/vnd.ms-outlook-pst']='Outlook PST database|pst|2142444e|8'
	['audio/mod']='Amiga MOD module|mod|4d2e4b|108'
	['application/x-ext-filesystem']='Linux ext2/3/4 filesystem|img|53ef|1080'
	['application/x-ms-shortcut']='Windows shortcut|lnk|4c0000000114020000000000c0000000'
	['audio/xm']='FastTracker XM module|xm|457874656e646564204d6f64756c65'
	['application/x-sqlite3']='SQLite database|db,sqlite,sqlite3|53514c69746520666f726d61742033'
	['audio/x-creative-voice']='Creative Voice audio (VOC)|voc|437265617469766520566f696365'
	['application/x-android-backup']='Android backup|ab|414e44524f4944204241434b5550'
	['image/jp2']='JPEG 2000 (JP2)|jp2|0000000c6a5020200d0a870a'
	['application/x-stata-dta']='Stata dataset|dta|3c53746174615f6474613e'
	['application/x-bittorrent']='BitTorrent metainfo|torrent|64383a616e6e6f756e6365'
	['image/vnd.radiance']='Radiance HDR image|hdr|233f52414449414e4345'
	['text/x-ascii-armor']='Armored ASCII block (PGP/PEM/SSH)|asc,pgp,gpg|2d2d2d2d2d424547494e'
	['image/webp']='WEBP image|webp|52494646????????57454250'
	['audio/wav']='WAV audio|wav|52494646????????57415645'
	['video/avi']='AVI video|avi|52494646????????41564920'
	['video/amv']='AMV video|amv|52494646????????414d5620'
	['audio/aiff']='AIFF audio|aiff,aif|464f524d????????41494646'
	['audio/aifc']='AIFC audio|aifc|464f524d????????41494643'
	['video/quicktime']='QuickTime MOV video|mov|????????6674797071742020'
	['audio/mp4']='M4A audio|m4a|????????667479704d344120'
	['video/m4v']='M4V video|m4v|????????667479704d345620'
	['image/heic']='HEIC/HEIF image|heic,heif,hif|????????6674797068656963'
	['image/heix']='HEIC/HEIF image|heic,heif,hif|????????6674797068656978'
	['image/heif']='HEIC/HEIF image|heic,heif,hif|????????6674797068656966'
	['image/heif-mif1']='HEIC/HEIF image|heic,heif,hif|????????667479706d696631'
	['image/heif-msf1']='HEIC/HEIF image|heic,heif,hif|????????667479706d736631'
	['image/avif']='AVIF image|avif|????????6674797061766966'
	['image/avif-sequence']='AVIF image|avif|????????6674797061766973'
	['image/jp2-ftyp']='JPEG 2000 (JP2)|jp2|????????667479706a703220'
	['video/3gpp-4']='3GP video|3gp|????????6674797033677034'
	['video/3gpp-5']='3GP video|3gp|????????6674797033677035'
	['video/3gpp-6']='3GP video|3gp|????????6674797033677036'
	['video/3gpp2']='3G2 video|3g2|????????6674797033673261'
	['video/mp4']='MP4 video|mp4|????????6674797069736f6d'
	['video/mp4-iso2']='MP4 video|mp4|????????6674797069736f32'
	['video/mp4-mp41']='MP4 video|mp4|????????667479706d703431'
	['video/mp4-mp42']='MP4 video|mp4|????????667479706d703432'
	['video/mp4-avc1']='MP4 video|mp4|????????6674797061766331'
	['application/dash+xml']='DASH video|mpd,m4s,mp4|????????6674797064617368'
	['video/f4v']='Flash F4V video|f4v|????????6674797066347620'
	['image/x-ani']='Windows animated cursor|ani|52494646????????41434f4e'
	['image/x-ilbm']='Amiga ILBM image|iff,lbm|464f524d????????494c424d'
	['audio/x-8svx']='Amiga 8SVX audio|iff,8svx|464f524d????????38535658'
	['audio/x-maud']='Amiga MAUD audio|maud|464f524d????????4d415544'
	['audio/rmidi']='RIFF MIDI (RMID)|rmi|52494646????????524d4944'
	['audio/x-soundfont']='SoundFont SF2|sf2|52494646????????7366626b'
	['video/hevc-hvc1']='HEVC video|hevc,h265|????????6674797068766331'
	['video/hevc-hev1']='HEVC video|hevc,h265|????????6674797068657631'
	['video/av1']='AV1 video|av1|????????6674797061763031'
	['video/x-divx']='DivX video|divx|????????6674797044495658'
	['audio/mp4-m4b']='M4B audiobook|m4b|????????667479704d344220'
	['image/x-xcf']='GIMP XCF image|xcf|67696d7020786366'
	['video/x-ms-asf']='ASF media (WMA/WMV)|wma,wmv,asf|3026b2758e66cf11'
	['application/x-msoffice-ole']='MS Office/OLE compound|doc,xls,ppt,msi,cfg|d0cf11e0a1b11ae1'
	['image/vnd.djvu']='DjVu document|djvu,djv|41542654464f524d'
	['application/x-ms-reader-lit']='MS Reader LIT e-book|lit|49544f4c49544c53'
	['application/x-vhdx']='Hyper-V VHDX disk|vhdx|7668647866696c65'
	['audio/amr-wb']='AMR-WB speech audio|amr|2321414d522d5742'
	['application/x-psx-exe']='PlayStation executable|exe|50532d5820455845'
	['application/x-android-boot']='Android boot image|img|414e44524f494421'
	['application/x-ms-kernel-dump']='Windows kernel dump|dmp|5041474544554d50'
	['application/x-ms-kernel-dump-64']='Windows kernel dump (64-bit)|dmp|5041474544553634'
	['application/vnd.corel-draw']='CorelDRAW document|cdr|52494646????????434452'
	['application/x-archive-ar']='AR archive (deb/static lib)|a,deb|213c617263683e'
	['application/x-stuffit']='StuffIt archive|sit|53747566664974'
	['image/x-canon-cr2']='Canon CR2 raw image|cr2|49492a00????????4352'
	['image/vnd.radiance-rgbe']='Radiance HDR image|hdr|233f52474245'
	['application/x-7z-compressed']='7-Zip archive|7z|377abcaf271c'
	['application/x-rar-compressed']='RAR archive|rar|526172211a07'
	['application/x-cpio-newc']='CPIO archive (newc)|cpio|303730373031'
	['application/x-cpio-odc']='CPIO archive (odc)|cpio|303730373037'
	['application/x-ace']='ACE archive|ace|2a2a4143452a'
	['application/rtf']='RTF document|rtf|7b5c72746631'
	['application/x-luks']='LUKS encrypted volume|luks,img|4c554b53babe'
	['image/fits']='FITS astronomy image|fits|53494d504c45'
	['application/x-arrow']='Apache Arrow IPC data|arrow|4152524f5731'
	['application/x-matlab-mat']='MATLAB MAT-file|mat|4d41544c4142'
	['image/jxl']='JPEG XL container|jxl|0d0a870a0a'
	['text/xml']='XML document|xml,svg,fb2,rss,xsl,plist|3c3f786d6c'
	['audio/amr']='AMR speech audio|amr|2321414d52'
	['application/x-xz']='XZ stream|xz,txz|fd377a585a'
	['application/x-ms-wim']='Windows Imaging archive|wim|4d5357494d'
	['audio/x-nsf']='NES sound file|nsf|4e45534d1a'
	['application/x-redis-rdb']='Redis RDB snapshot|rdb|5245444953'
	['video/ftyp-generic']='MP4/QuickTime container|mp4,m4a,mov,3gp,heic|????????66747970'
	['image/png']='PNG image|png|89504e47'
	['image/jp2-codestream']='JPEG 2000 codestream|j2k,jpc|ff4fff51'
	['image/gif']='GIF image|gif|47494638'
	['image/tiff']='TIFF image (little-endian)|tif,tiff|49492a00'
	['image/tiff-be']='TIFF image (big-endian)|tif,tiff|4d4d002a'
	['image/vnd.adobe.photoshop']='Photoshop PSD image|psd,pdd|38425053'
	['image/x-dds']='DirectDraw Surface texture|dds|44445320'
	['image/x-exr']='OpenEXR image|exr|762f3101'
	['image/x-cur']='Windows cursor|cur|00020000'
	['image/x-icon']='ICO icon / TrueType font|ico,ttf,otf|00010000'
	['image/x-icns']='Apple ICNS icon|icns|69636e73'
	['image/svg+xml']='SVG image|svg|3c737667'
	['application/x-riff']='RIFF container|wav,avi,webp|52494646'
	['audio/dff']='DSDIFF audio (DFF)|dff|46524d38'
	['audio/x-caf']='Apple CAF audio|caf|63616666'
	['audio/dsf']='DSD streamfile audio (DSF)|dsf|44534420'
	['audio/flac']='FLAC audio|flac|664c6143'
	['application/ogg']='OGG media|ogg,oga,opus,ogv,ogx|4f676753'
	['audio/midi']='MIDI music|mid,midi,rmi,kar|4d546864'
	['audio/basic']='NeXT/Sun AU audio|au,snd|2e736e64'
	['audio/ape']='Monkey Audio (APE)|ape|4d414320'
	['audio/wavpack']='WavPack audio|wv|7770766b'
	['audio/musepack-sv8']='Musepack audio (SV8)|mpc|4d50434b'
	['audio/tta']='True Audio (TTA)|tta|54544131'
	['audio/shorten']='Shorten audio|shn|616a6b67'
	['audio/it']='Impulse Tracker module|it|494d504d'
	['video/x-matroska']='Matroska/WebM video|mkv,webm,mka,mks|1a45dfa3'
	['video/mpeg']='MPEG program stream|mpg,mpeg,vob,ps|000001ba'
	['video/mpeg-elementary']='MPEG elementary video|m2v,mpv,mpg|000001b3'
	['video/vnd.rn-realmedia']='RealMedia video|rm,rmvb|2e524d46'
	['application/mxf']='MXF video|mxf|060e2b34'
	['application/zip']='ZIP/Office document|zip,docx,xlsx,pptx,odt,jar,apk,epub|504b0304'
	['application/zip-empty']='ZIP archive (empty)|zip|504b0506'
	['application/zip-spanned']='ZIP archive (spanned)|zip|504b0708'
	['application/zstd']='Zstandard stream|zst|28b52ffd'
	['application/x-lz4']='LZ4 frame|lz4|04224d18'
	['application/x-lzma']='LZMA-alone stream|lzma|5d000080'
	['application/x-lzop']='LZO compressed archive|lzo|894c5a4f'
	['application/vnd.ms-cab-compressed']='MS Cabinet archive|cab|4d534346'
	['application/x-rpm']='RPM package|rpm|edabeedb'
	['application/parquet']='Apache Parquet data|parquet|50415231'
	['application/pdf']='PDF document|pdf|25504446'
	['application/postscript']='PostScript/EPS document|ps,eps,ai|25215053'
	['application/vnd.ms-htmlhelp']='MS Compiled HTML (CHM)|chm|49545346'
	['font/otf']='OpenType (CFF) font|otf|4f54544f'
	['font/collection']='TrueType collection|ttc|74746366'
	['font/woff']='WOFF font|woff|774f4646'
	['font/woff2']='WOFF2 font|woff2|774f4632'
	['application/x-elf']='ELF binary|so,bin,elf,o,ko|7f454c46'
	['application/x-mach-o-be32']='Mach-O binary (32-bit BE)|bin|feedface'
	['application/x-mach-o-le32']='Mach-O binary (32-bit LE)|bin|cefaedfe'
	['application/x-mach-o-be64']='Mach-O binary (64-bit BE)|bin|feedfacf'
	['application/x-mach-o-le64']='Mach-O binary (64-bit LE)|bin|cffaedfe'
	['application/x-java-class']='Java class / Mach-O fat binary|class,bin|cafebabe'
	['application/wasm']='WebAssembly module|wasm|0061736d'
	['application/x-dex']='Android DEX bytecode|dex,odex|6465780a'
	['application/x-ms-registry-hive']='Windows registry hive|dat,hive,reg|72656766'
	['application/vnd.tcpdump-pcap']='pcap packet capture|pcap,cap|a1b2c3d4'
	['application/vnd.tcpdump-pcap-swapped']='pcap packet capture (swapped)|pcap,cap|d4c3b2a1'
	['application/vnd.tcpdump-pcapng']='pcapng packet capture|pcapng|0a0d0d0a'
	['application/avro']='Apache Avro object container|avro|4f626a01'
	['application/x-chrome-extension']='Chrome extension (CRX)|crx|43723234'
	['application/x-qcow2']='QEMU copy-on-write disk|qcow,qcow2|514649fb'
	['application/x-vmdk']='VMware VMDK disk|vmdk|4b444d56'
	['image/tiff-big']='TIFF image (BigTIFF)|tif,tiff|4d4d002b'
	['image/x-olympus-orf']='Olympus ORF raw image|orf|4949524f'
	['image/x-panasonic-rw2']='Panasonic RW2 raw image|rw2|49495500'
	['image/jxr']='JPEG XR image|jxr,wdp,hdp|4949bc01'
	['image/flif']='FLIF image|flif|464c4946'
	['image/x-ktx']='KTX/KTX2 texture|ktx,ktx2|ab4b5458'
	['image/qoi']='QOI image|qoi|716f6966'
	['audio/x-optimfrog']='OptimFROG audio|ofr|4f465220'
	['audio/vnd.dts']='DTS audio|dts|7fff8001'
	['audio/x-sid']='Commodore SID tune|sid|50534944'
	['audio/x-vgm']='Video Game Music tune|vgm|56676d20'
	['video/x-nut']='NUT video|nut|6e75742f'
	['application/x-xar']='XAR archive|xar|78617221'
	['application/x-git-pack']='Git packfile / Quake PAK|pack,pak|5041434b'
	['application/x-mpq']='Blizzard MPQ archive|mpq|4d50511a'
	['application/x-doom-iwad']='Doom IWAD game archive|wad|49574144'
	['application/x-doom-pwad']='Doom PWAD game archive|wad|50574144'
	['application/x-dms']='Amiga DMS archive|dms|444d5321'
	['application/x-nes-rom']='NES ROM image|nes|4e45531a'
	['application/x-n64-rom']='Nintendo 64 ROM|n64,z64|80371240'
	['application/x-n64-rom-swapped']='Nintendo 64 ROM (swapped)|n64,v64|37804012'
	['application/x-genesis-rom']='SEGA Mega Drive ROM|md,gen|53454741'
	['application/x-winhelp']='Windows Help file|hlp|3f5f0300'
	['application/x-ereader-pdb']='eReader PDB e-book|pdb|504e5264'
	['text/x-php']='PHP script|php|3c3f7068'
	['application/x-ms-minidump']='Windows minidump|dmp|4d444d50'
	['application/x-java-serialized']='Java serialized object|ser|aced0005'
	['application/x-java-keystore']='Java keystore|jks|feedfeed'
	['application/x-xfs-filesystem']='XFS filesystem|img|58465342'
	['application/x-hdf5']='HDF5 dataset|h5,hdf5|89484446'
	['application/x-netcdf']='NetCDF classic dataset|nc|43444601'
	['application/x-netcdf-64']='NetCDF 64-bit dataset|nc|43444602'
	['application/x-r-data']='R binary data|rdata,rds|52445832'
	['application/x-bam']='BAM sequence data|bam|42414d01'
	['application/x-cram']='CRAM sequence data|cram|4352414d'
	['application/x-git-index']='Git index|index|44495243'
	['audio/x-med']='Amiga MED module|med|4d4d443?'
	['image/jpeg']='JPEG image|jpg,jpeg,jfif|ffd8ff'
	['image/x-pcx']='PCX image|pcx|0a0000'
	['image/x-pcx-2']='PCX image|pcx|0a0200'
	['image/x-pcx-3']='PCX image|pcx|0a0300'
	['image/x-pcx-5']='PCX image|pcx|0a0500'
	['audio/mpeg-id3']='MP3 audio (ID3v2 tag)|mp3|494433'
	['audio/musepack']='Musepack audio|mpc|4d502b'
	['video/x-flv']='Flash video (FLV)|flv|464c56'
	['video/x-bink']='Bink video|bik,bk2|42494b'
	['application/x-bzip2']='BZIP2 stream|bz2,tbz2|425a68'
	['application/x-compress']='compress (.Z) archive|z|1f9d8d'
	['application/x-zoo']='ZOO archive|zoo|5a4f4f'
	['application/x-shockwave-flash-compressed']='Shockwave Flash (compressed)|swf|435753'
	['application/x-shockwave-flash']='Shockwave Flash|swf|465753'
	['application/x-shockwave-flash-lzma']='Shockwave Flash (LZMA)|swf|5a5753'
	['image/x-portable-arbitrarymap']='PAM image|pam|50370a'
	['audio/x-mtm']='Multitracker module|mtm|4d544d'
	['font/x-type1-pfb']='Type 1 font (PFB)|pfb|800106'
	['application/x-orc']='Apache ORC data|orc|4f5243'
	['image/jxl-codestream']='JPEG XL codestream|jxl|ff0a'
	['image/bmp']='BMP image|bmp,dib|424d'
	['image/x-portable-bitmap']='PBM image|pbm|5034'
	['image/x-portable-graymap']='PGM image|pgm|5035'
	['image/x-portable-pixmap']='PPM image|ppm|5036'
	['audio/mpeg-raw']='MP3 audio (MPEG-1)|mp3|fffb'
	['audio/mpeg-raw-2']='MP3 audio (MPEG-2)|mp3|fff3'
	['audio/mpeg-raw-2-5']='MP3 audio (MPEG-2.5)|mp3|fff2'
	['audio/mpeg-raw-2-5-lsf']='MP3 audio (MPEG-2.5 LSF)|mp3|ffe3'
	['audio/aac']='AAC audio (ADTS)|aac,adts|fff1'
	['audio/aac-latm']='AAC audio (ADTS)|aac,adts|fff9'
	['application/gzip']='GZIP stream|gz,tgz|1f8b'
	['application/x-arj']='ARJ archive|arj|60ea'
	['application/x-shar']='Bourne shell archive|shar|7ffe'
	['application/x-msdownload']='DOS/PE executable|exe,dll,sys,ocx,scr|4d5a'
	['text/x-shellscript']='Script (#!)|sh,py,pl,rb,el,js,ts|2321'
)

# Magic_Nibbles <file> <count> : first bytes as one lowercase hex string
Magic_Nibbles() {
	head -c "$2" -- "$1" 2>/dev/null | od -An -v -tx1 | tr -d ' \n\t'
}

# Magic_Match <hex> <offset-bytes> <pattern> : nibble compare, '?' = any
Magic_Match() {
	local H=$1 Pos=$(( $2 * 2 )) P=$3 I C
	[ "${#H}" -lt $(( Pos + ${#P} )) ] && return 1
	for (( I=0; I<${#P}; I++ )); do
		C=${P:I:1}
		if [ "$C" != '?' ] && [ "${H:Pos+I:1}" != "$C" ]; then
			return 1
		fi
	done
	return 0
}

# Magic_Detect <hex> : prints "MIME|Name|ext,ext" of the best match
Magic_Detect() {
	local H=${1,,} Key Val Name Exts Pat Off Concrete Score Best BestScore
	# MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376
	if [ "${#H}" -ge 754 ] && [ "${H:0:2}" = '47' ] && [ "${H:376:2}" = '47' ] && [ "${H:752:2}" = '47' ]; then
		printf 'video/mp2t|MPEG-TS|ts,m2ts,mts'
		return 0
	fi
	Best='' BestScore=-1
	for Key in "${!Magic[@]}"; do
		Val=${Magic[$Key]}
		IFS='|' read -r Name Exts Pat Off <<< "$Val"
		Off=${Off:-0}
		if Magic_Match "$H" "$Off" "$Pat"; then
			Concrete=${Pat//\?/}
			Score=$(( ${#Concrete} * 1000 + ${#Pat} ))
			if [ "$Score" -gt "$BestScore" ]; then
				BestScore=$Score
				Best="$Key|$Name|$Exts"
			fi
		fi
	done
	[ -n "$Best" ] || return 1
	printf '%s' "$Best"
}

# Magic_Report <file> : one report line for a single file
Magic_Report() {
	local F=$1 H Detected Key Rest Name Exts Ext Verdict
	H=$(Magic_Nibbles "$F" 32774)
	[ -n "$H" ] || H='(empty)'
	if Detected=$(Magic_Detect "$H"); then
		Key=${Detected%%|*}
		Rest=${Detected#*|}
		Name=${Rest%%|*}
		Exts=${Rest#*|}
	else
		Key='' Name='?' Exts=''
	fi
	Ext=${F##*.}
	if [ "$Ext" = "${F##*/}" ]; then Ext='(none)'; else Ext=${Ext,,}; fi
	if [ "$Name" = '?' ]; then
		Verdict='UNKNOWN'
	elif [ "$Ext" = '(none)' ]; then
		Verdict='NO-EXT'
	elif case ",$Exts," in *",$Ext,"*) true ;; *) false ;; esac; then
		Verdict='MATCH'
	else
		Verdict='MISMATCH'
	fi
	printf '%s\n\tmagic: %s\n\tdetected: %s\n\textension: %s\n\tverdict: %s\n' \
		"$F" "${H:0:32}" "${Name:-UNKNOWN}" "$Ext" "$Verdict"
}

# Magic_Report_All : report every collected target
Magic_Report_All() {
	local F
	for F in "${Targets[@]}"; do
		Magic_Report "$F"
	done
	return 0
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

	# --magic (V17.5): magic-number detection report, then exit
	if [ "${Magic_Mode:-0}" -eq 1 ]; then
		Collect_Files
		if [ "${#Targets[@]}" -eq 0 ]; then
			Print_Warning 'Nothing to inspect.'
			return 1
		fi
		if [ "$Quiet" -eq 0 ]; then
			Draw_Line '='
			Print_Header "Magic-number report (${#Targets[@]} file(s))"
			Draw_Line '='
		fi
		Magic_Report_All
		return 0
	fi

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
		Print_Header "$(Tf 'Sorting %s file(s) - mode: %s, jobs: %s' "${#Targets[@]}" "$Modus" "$Max_Jobs")"
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
