#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : colors.sh                                                         #
# Version : 2.0                                                               #
# Desc    : Complete color toolkit - ANSI colors / print helpers              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

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

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
