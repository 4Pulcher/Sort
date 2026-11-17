#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : Sort.sh                                                           #
# Version : 16.0                                                              #
# Desc    : Threaded, colored file organizer built on the functions/ library  #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete rewrite of the Sort mainline as a thin driver over the isolated
# functions/ toolkit: it collects every file to treat into an array up front,
# classifies each file by MIME type / dimensions / size, and processes the
# array through a bounded pool of background jobs (threading). Verbose by
# default, with colored output via --colored.

# ---------------------------------------------------------------------------
# Library loading - the functions/ map at the repository root
# ---------------------------------------------------------------------------

# Resolve the directory this script lives in, so Sort.sh works from anywhere.
Lib_Dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/functions

# Load only what this driver needs; each module is standalone.
. "$Lib_Dir/deps/deps.sh"
. "$Lib_Dir/colors/colors.sh"
. "$Lib_Dir/file/file.sh"
. "$Lib_Dir/mime/mime.sh"
. "$Lib_Dir/hash/hash.sh"
. "$Lib_Dir/imagemagick/imagemagick.sh"
. "$Lib_Dir/ffmpeg/ffmpeg.sh"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

Modus='Print'                                              # copy / move / Print (dry-run preview)
Replace='No'                                               # overwrite existing targets?
Rename=''                                                  # '' = folder_name, sha256sum, long, short, random
Append=''                                                  # '' = original extension, none, mime, mime-sub
Quiet=0                                                    # 1 = per-file details suppressed
Max_Jobs=$(command -v nproc >/dev/null && nproc || echo 4) # thread pool size

Files=()   # raw arguments that are files/directories
Targets=() # every single file to treat, collected up front

# ---------------------------------------------------------------------------
# Usage - the short reminder printed when no arguments are given
# ---------------------------------------------------------------------------

Usage() {
	Print_Header 'Sort 16.0 - threaded file organizer'
	Print_Message 'Usage: Sort.sh [options] <file|directory> ...'
	printf '\n'
	Print_Message 'Common starts:'
	printf '\n'
	printf '\t%s\n' 'Sort.sh --copy --replace ~/Pictures/2Sort'
	printf '\t%s\n' 'Sort.sh --move --rename=sha256sum --extension=none .'
	printf '\t%s\n' 'Sort.sh --colored --jobs=8 ~/Downloads'
	printf '\n'
	Print_Message 'Use --help for the full option list.'
}

# ---------------------------------------------------------------------------
# Help - the complete option reference
# ---------------------------------------------------------------------------

Help() {
	Print_Header 'Sort 16.0 - threaded file organizer'
	Print_Message 'Sorts files into a MIME-type tree: <mime>/<form-or-size>/...'
	printf '\n'
	Print_Header 'Actions' '='
	printf '\t%s\n' '--copy            Copy every file to its sorted location'
	printf '\t%s\n' '--move            Move every file to its sorted location'
	printf '\t%s\n' '(default)         Preview only - print source <=> target'
	printf '\n'
	Print_Header 'Naming' '='
	printf '\t%s\n' '--rename=sha256sum   New name from the SHA256 of the file'
	printf '\t%s\n' '--rename=long        Keep the full base name (with extension)'
	printf '\t%s\n' '--rename=short       Base name without its extension'
	printf '\t%s\n' '--rename=random      Random numeric name'
	printf '\t%s\n' '--rename=(empty)     <folder>_<name> (default)'
	printf '\n'
	Print_Header 'Extensions' '='
	printf '\t%s\n' '--extension=none       No extension at all'
	printf '\t%s\n' '--extension=mime       .image.png style, from the MIME type'
	printf '\t%s\n' '--extension=mime-sub   .png style, from the MIME sub type'
	printf '\t%s\n' '--extension=(empty)    Original extension (default)'
	printf '\n'
	Print_Header 'Behaviour' '='
	printf '\t%s\n' '--replace         Overwrite existing targets instead of ~(N)'
	printf '\t%s\n' '--colored         Force colored output (auto-detected on a tty)'
	printf '\t%s\n' '--quiet           Per-file details off; summary only'
	printf '\t%s\n' '--jobs=N          Thread pool size (default: nproc, min 1)'
	printf '\t%s\n' '--usage           Short reminder'
	printf '\t%s\n' '--help            This help'
	printf '\t%s\n' '--version         Print the version'
	printf '\n'
	Print_Header 'Destination layout' '='
	printf '\t%s\n' 'image  ->  <mime>/<Square|Portrait|Landscape>/<WxH>'
	printf '\t%s\n' 'video  ->  <mime>/<WxH>/<HH-MM-SS>'
	printf '\t%s\n' 'other  ->  <mime>/<Byte..TeraByte>/<human size>'
	printf '\n'
	Print_Message 'Tools are proposed for install on first use (deps init-system).'
}

# ---------------------------------------------------------------------------
# Argument parsing - options first, everything else becomes a file argument
# ---------------------------------------------------------------------------

Parse_Arguments() {
	local Item

	for Item in "$@"; do
		case "$Item" in
		--copy)
			Modus='Copy'
			;;
		--move)
			Modus='Move'
			;;
		--replace)
			Replace='Yes'
			;;
		--rename=*)
			Rename=${Item#--rename=}
			;;
		--extension=*)
			Append=${Item#--extension=}
			;;
		--colored)
			Color_Enable
			;;
		--quiet)
			Quiet=1
			;;
		--jobs=*)
			Max_Jobs=${Item#--jobs=}
			[ "$Max_Jobs" -ge 1 ] 2>/dev/null || Max_Jobs=1
			;;
		--usage)
			Usage
			exit 0
			;;
		--help | -h)
			Help
			exit 0
			;;
		--version)
			printf 'Sort 16.0\n'
			exit 0
			;;
		--)
			shift
			;;
		-*)
			Print_Warning "Unknown option: $Item (ignored)"
			;;
		*)
			Files+=("$Item")
			;;
		esac
	done
}

# ---------------------------------------------------------------------------
# File collection - build the array of files to treat at the beginning
# ---------------------------------------------------------------------------

Collect_Files() {
	local Item File

	for Item in "${Files[@]}"; do
		if [ -d "$Item" ]; then
			# A directory: every regular file below it joins the array
			while IFS= read -r -d '' File; do
				Targets+=("$File")
			done < <(find "$Item" -type f -print0 2>/dev/null)
		elif [ -f "$Item" ]; then
			Targets+=("$Item")
		else
			Print_Warning "Not a file or directory: $Item"
		fi
	done

	[ "$Quiet" -eq 1 ] || Print_Info "Files to treat: ${#Targets[@]}"
}

# ---------------------------------------------------------------------------
# Classification helpers - one destination sub-path per file kind
# ---------------------------------------------------------------------------

# Aspect form from a WxH string: Square / Portrait / Landscape
Image_Form() {
	local WxH=$1 W H

	W=${WxH%x*}
	H=${WxH#*x}

	if [ "$W" = "$H" ]; then
		printf 'Square'
	elif [ "$H" -gt "$W" ] 2>/dev/null; then
		printf 'Portrait'
	else
		printf 'Landscape'
	fi
}

# Duration as a filename-safe HH-MM-SS tag
Video_Duration_Tag() {
	local Seconds H M S

	Seconds=$(Get_Duration "$1") || return 1
	Seconds=${Seconds%.*}
	Seconds=${Seconds:-0}

	H=$((Seconds / 3600))
	M=$(((Seconds % 3600) / 60))
	S=$((Seconds % 60))

	printf '%02d-%02d-%02d' "$H" "$M" "$S"
}

# Size class as a directory name (Byte .. TeraByte)
File_Size_Category() {
	local Size

	Size=$(Get_File_Size "$1") || return 1

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

# ---------------------------------------------------------------------------
# Name / extension builders - driven by --rename and --extension
# ---------------------------------------------------------------------------

Build_Name() {
	local File=$1 Folder

	case "$Rename" in
	sha256sum)
		Get_Hash sha256 "$File" || return 1
		;;
	random)
		printf 'RND-%s-%s' "$RANDOM" "$SECONDS"
		;;
	long)
		Get_File_Base "$File"
		;;
	short)
		Get_File_Name "$File"
		;;
	*)
		# Default: <folder>_<name>, flat and filename-safe;
		# a file in the current directory has no folder part
		Folder=$(Get_File_Dir "$File")
		Folder=${Folder##*/}
		[ "$Folder" = '.' ] && Folder=''

		if [ -n "$Folder" ]; then
			printf '%s_%s' "$Folder" "$(Get_File_Name "$File")"
		else
			Get_File_Name "$File"
		fi
		;;
	esac
}

Build_Extension() {
	local File=$1 Mime=$2

	case "$Append" in
	none)
		printf ''
		;;
	mime)
		printf '.%s' "${Mime//\//.}"
		;;
	mime-sub)
		printf '.%s' "${Mime#*/}"
		;;
	*)
		printf '.%s' "$(Get_File_Ext "$File")"
		;;
	esac
}

# ---------------------------------------------------------------------------
# Per-file worker - classify, build the target, then copy / move / preview
# Sets Status (COPIED / MOVED / PREVIEW / SKIPPED / FAILED) for the tally.
# ---------------------------------------------------------------------------

Process_File() {
	local File=$1
	local Mime Main Sub Name Ext NewDir New Count=0

	Status='FAILED'

	[ -f "$File" ] || {
		Print_Error "Not a regular file: $File"
		return 1
	}

	# MIME type drives everything; no type -> no destination
	Mime=$(Get_MIME_Type "$File") || {
		Print_Error "No MIME type for: $File"
		return 1
	}
	Main=${Mime%%/*}

	# Sub-path per kind: images by shape, videos by geometry+length, rest by size
	case "$Main" in
	image)
		local WxH
		WxH=$(Get_Image_WxH "$File") || WxH='unknown'
		Sub="$(Image_Form "$WxH")/$WxH"
		;;
	video)
		local WxH Dur
		WxH=$(Get_Media_WxH "$File") || WxH='unknown'
		Dur=$(Video_Duration_Tag "$File") || Dur='unknown'
		Sub="$WxH/$Dur"
		;;
	*)
		Sub="$(File_Size_Category "$File")/$(Get_File_Size_Human "$File")"
		;;
	esac

	NewDir="$Mime/$Sub"

	# New name and extension
	Name=$(Build_Name "$File") || {
		Print_Error "Cannot build a name for: $File"
		return 1
	}
	Ext=$(Build_Extension "$File" "$Mime")

	mkdir -p -- "$NewDir" || {
		Print_Error "Cannot create: $NewDir"
		return 1
	}
	New="$NewDir/$Name$Ext"

	# Without --replace, never clobber: slide a ~(N) counter in
	if [ ! "$Replace" = 'Yes' ]; then
		while [ -e "$New" ]; do
			Count=$((Count + 1))
			New="$NewDir/$Name~($Count)$Ext"
		done
	fi

	# Already in place -> nothing to do
	if [ "${File#./}" = "$New" ]; then
		Status='SKIPPED'
		[ "$Quiet" -eq 1 ] || Print_Info "Same place: $File"
		return 0
	fi

	case "$Modus" in
	Copy)
		if cp -v -- "$File" "$New"; then
			Status='COPIED'
			Print_Ok "$File -> $New"
		else
			Print_Error "Copy failed: $File"
			return 1
		fi
		;;
	Move)
		if mv -v -- "$File" "$New"; then
			Status='MOVED'
			Print_Ok "$File -> $New"
		else
			Print_Error "Move failed: $File"
			return 1
		fi
		;;
	*)
		Status='PREVIEW'
		Print_Message "$File <=> $New"
		;;
	esac
}

# ---------------------------------------------------------------------------
# Threading - run the worker over the array with a bounded job pool
# Each job writes its own output and status tag, so lines never interleave.
# ---------------------------------------------------------------------------

Run_Threads() {
	local Tmp Idx=0 Total=$# Rc
	local -i Done_Copied=0 Done_Moved=0 Done_Preview=0 Done_Skipped=0 Done_Failed=0

	Tmp=$(mktemp -d) || return 1

	# Launch every file, keeping at most Max_Jobs running at once
	while [ "$Idx" -lt "$Total" ]; do
		while [ "$(jobs -rp | wc -l)" -ge "$Max_Jobs" ]; do
			wait -n || true
		done

		(
			Process_File "${@:$((Idx + 1)):1}"
			printf '%s\n' "$Status" >"$Tmp/tag.$Idx"
		) >"$Tmp/out.$Idx" 2>&1 &

		Idx=$((Idx + 1))
	done
	wait

	# Report in submission order so the log stays readable
	for Idx in $(seq 0 $((Total - 1))); do
		[ "$Quiet" -eq 1 ] || cat "$Tmp/out.$Idx"

		case "$(cat "$Tmp/tag.$Idx" 2>/dev/null)" in
		COPIED) Done_Copied+=1 ;;
		MOVED) Done_Moved+=1 ;;
		PREVIEW) Done_Preview+=1 ;;
		SKIPPED) Done_Skipped+=1 ;;
		*) Done_Failed+=1 ;;
		esac
	done

	rm -rf -- "$Tmp"

	# Summary
	printf '\n'
	Print_Header 'Summary'
	Print_Message "Copied : $Done_Copied"
	Print_Message "Moved  : $Done_Moved"
	Print_Message "Preview: $Done_Preview"
	Print_Message "Skipped: $Done_Skipped"
	[ "$Done_Failed" -eq 0 ] && Print_Ok "Failed : $Done_Failed" || Print_Error "Failed : $Done_Failed"

	[ "$Done_Failed" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Interrupt handling - stop the pool and clean up
# ---------------------------------------------------------------------------

On_Interrupt() {
	Print_Error 'Interrupted - stopping running jobs...'
	jobs -rp | xargs -r kill 2>/dev/null
	wait 2>/dev/null
	exit 130
}

trap On_Interrupt INT

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Main() {
	# No arguments at all: show the short usage
	if [ $# -eq 0 ]; then
		Usage
		return 0
	fi

	Parse_Arguments "$@"

	# Init-system: propose one batch install for the optional media tools
	if [ "$Quiet" -eq 0 ]; then
		Deps_Init identify ffprobe || true
	fi

	# The array of files to treat, built before any work starts
	Collect_Files

	if [ "${#Targets[@]}" -eq 0 ]; then
		Print_Warning 'Nothing to treat.'
		return 1
	fi

	[ "$Quiet" -eq 1 ] || Print_Header "Sorting ${#Targets[@]} file(s) - mode: $Modus, jobs: $Max_Jobs"

	Run_Threads "${Targets[@]}"
}

Main "$@"

echo "Thanks for using HEjder scripts!"
