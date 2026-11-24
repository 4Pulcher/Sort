#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : file.sh                                                           #
# Version : 2.0                                                               #
# Desc    : Complete file toolkit - coreutils / file(1)                        #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

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

# Size class name from a byte count - shared core for size-based segments.
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

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
