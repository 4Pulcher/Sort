#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : get_file.sh                                                       #
# Version : 1.0                                                               #
# Desc    : Legacy FUNCTIONS adapters - file names / folders / sizes / hash   #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Compatibility layer for the original FUNCTIONS library: the lowercase
# get_file_* helpers expected by Sort.sh (V15.1). Each adapter is a thin
# wrapper over the modern functions/ toolkit and prints its result on
# stdout, returning non-zero on failure.

# Load the modern toolkit this layer is built on
_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../functions" && pwd)

. "$_LIB_DIR/file/file.sh"
. "$_LIB_DIR/hash/hash.sh"

# ---------------------------------------------------------------------------
# Names
# ---------------------------------------------------------------------------

# get_file_sha256sum <file> : SHA256 checksum of the file
get_file_sha256sum() {
	[ -e "$1" ] || return 1
	Get_Hash sha256 "$1"
}

# get_file_name_long <file> : full base name, extension included
get_file_name_long() {
	[ -n "$1" ] || return 1
	Get_File_Base "$1"
}

# get_file_name <file> : base name without its extension
get_file_name() {
	[ -n "$1" ] || return 1
	Get_File_Name "$1"
}

# get_file_folder <file> : name of the containing folder (filename-safe)
get_file_folder() {
	local Dir
	Dir=$(Get_File_Dir "$1") || return $?
	Dir=${Dir##*/}
	[ -n "$Dir" ] || Dir='/'
	printf '%s' "$Dir"
}

# get_file_extension <file> : extension without the leading dot
get_file_extension() {
	[ -n "$1" ] || return 1
	Get_File_Ext "$1"
}

# ---------------------------------------------------------------------------
# Sizes
# ---------------------------------------------------------------------------

# get_file_size_Category <file> : size class as a directory name
get_file_size_Category() {
	local Size

	Size=$(Get_File_Size "$1") || return $?

	if [ "$Size" -lt 1024 ]; then
		printf 'Byte'
	elif [ "$Size" -lt 1048576 ]; then
		printf 'KiloByte'
	elif [ "$Size" -lt 1073741824 ]; then
		printf 'MegaByte'
	elif [ "$Size" -lt 1099511627776 ]; then
		printf 'GigaByte'
	else
		printf 'TeraByte'
	fi
}

# get_file_size_short <file> : human-readable size (du -h style)
get_file_size_short() {
	[ -e "$1" ] || return 1
	Get_File_Size_Human "$1"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
