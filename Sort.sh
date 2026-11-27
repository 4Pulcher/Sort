#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort-V18.sh                                                           #
# Version : 18                                                              #
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
