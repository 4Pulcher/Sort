#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : hash.sh                                                           #
# Version : 2.1                                                               #
# Desc    : Complete checksum toolkit - md5 / SHA family / crc32 / blake2      #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

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

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
