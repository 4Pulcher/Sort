#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : deps.sh                                                           #
# Version : 2.0                                                               #
# Desc    : Init-system for external tools - installer / privilege detection  #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

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
			read -r Answer </dev/tty || Answer=""
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

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
