#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : compression.sh                                                    #
# Version : 2.0                                                               #
# Desc    : Archive toolkit - tar / gz / bz2 / xz / zst / zip / 7z / rar      #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

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

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
