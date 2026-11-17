#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : get_mime.sh                                                       #
# Version : 1.0                                                               #
# Desc    : Legacy FUNCTIONS adapters - MIME type / main / sub                #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Compatibility layer for the original FUNCTIONS library: the lowercase
# get_mime_* helpers expected by Sort.sh (V15.1). Each adapter is a thin
# wrapper over the modern functions/mime toolkit and prints its result on
# stdout, returning non-zero on failure.

# Load the modern toolkit this layer is built on
_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../functions" && pwd)

. "$_LIB_DIR/mime/mime.sh"

# ---------------------------------------------------------------------------
# MIME getters
# ---------------------------------------------------------------------------

# get_mime <file> : full MIME type (e.g. image/png)
get_mime() {
	[ -e "$1" ] || return 1
	Get_MIME_Type "$1"
}

# get_mime_sub <file> : sub type (e.g. png)
get_mime_sub() {
	[ -e "$1" ] || return 1
	Get_MIME_Sub "$1"
}

# get_mime_MAIN <file> : main type in upper case (e.g. IMAGE)
get_mime_MAIN() {
	local Main

	[ -e "$1" ] || return 1
	Main=$(Get_MIME_Main "$1") || return $?
	printf '%s' "${Main^^}"
}

# get_MIME <file> : full MIME type, used as a directory name (e.g. image/png)
get_MIME() {
	[ -e "$1" ] || return 1
	Get_MIME_Type "$1"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
