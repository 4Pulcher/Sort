#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : hash.sh                                                           #
# Version : 1.0                                                               #
# Desc    : Checksums (md5sum / sha*sum)                                      #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Checksum helpers: MD5 and the SHA family via the md5sum/sha*sum toolset.

Get_MD5Sum() {
	local File=$1
	local Sum

	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

Get_SHA_Keys() {
	local CommandName=$1
	local File=$2
	local Sum

	if [[ ! -x "/usr/bin/$CommandName" ]]; then
		printf 'ERROR'
		return 1
	fi

	Sum=$("/usr/bin/$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

Get_SHA256Sum() {
	local File=$1
	local Sum

	Sum=$(sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
