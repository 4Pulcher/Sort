#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : hash.sh                                                           #
# Version : 2.0                                                               #
# Desc    : Complete checksum toolkit - md5 / SHA family / crc32 / blake2      #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of checksum tools: the md5/SHA family, crc32,
# blake2, a generic dispatcher, string hashing, verification, comparison and
# duplicate finding. Every function prints its result on stdout and returns
# non-zero on failure. No globals required.

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
# Verification and comparison
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

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
