#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : core.sh                                                           #
# Version : 1.0                                                               #
# Desc    : Organizer core logic                                              #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# The organizer core: dynamic path-segment resolver, argument parsing and validation, the safe copy/move/remove executor, the recursive Sort engine and the built-in help screen.

Resolve_Path_Segment() {
	local Req=${1,,}
	local File=$2

	case "$Req" in
	# Birth-time date components.
	year)
		Get_Date_Part "$File" '+%Y' '0000'
		;;
	month)
		Get_Date_Part "$File" '+%m' '00'
		;;
	day)
		Get_Date_Part "$File" '+%d' '00'
		;;
	year+month)
		Get_Date_Part "$File" '+%Y/%m' '0000/00'
		;;
	year+month+day)
		Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00'
		;;

	# Original extension and MIME components.
	extension)
		Get_File_Ext "$File"
		;;
	mime)
		printf '%s' "${MIME^^}"
		;;
	mime-main)
		printf '%s' "${MIMEMain^^}"
		;;
	mime-sub)
		printf '%s' "${MIMESub^^}"
		;;

	# Size and format values behave differently for media and other files.
	size | format | size+format | format+size)
		if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
			local Dimensions MediaFormat

			# Images are inspected by identify; videos by ffprobe.
			if [[ "$MIMEMain" == "image" ]]; then
				Dimensions=$(Get_Image_WxH "$File")
			else
				Dimensions=$(Get_Media_WxH "$File")
			fi

			MediaFormat=$(Get_WxH_Format "$Dimensions")

			if [[ "$MediaFormat" == "ZERO" ]]; then
				printf 'ZERO'
			elif [[ "$Req" == "size" ]]; then
				printf '%s' "$Dimensions"
			elif [[ "$Req" == "format" ]]; then
				printf '%s' "$MediaFormat"
			else
				printf '%s/%s' "$MediaFormat" "$Dimensions"
			fi
		else
			# For non-media files, convert the byte count to a unit label.
			local Bytes Value UnitIndex Divisor
			local -a Units

			Bytes=$(Get_File_Size "$File")
			Value=$Bytes
			UnitIndex=0
			Divisor=1000
			Units=("B" "KB" "MB" "GB" "TB" "PB")

			# size+format uses binary units; format values use decimal units.
			if [[ "$Req" == "size+format" ]]; then
				Divisor=1024
				Units=("B" "KiB" "MiB" "GiB" "TiB")
			elif [[ "$Req" == format* ]]; then
				Divisor=1000
				Units=("Byte" "Kilo" "Mega" "Giga" "Tera")
			fi

			# Divide until the value fits the selected unit or units run out.
			while ((Value >= Divisor && UnitIndex < ${#Units[@]} - 1)); do
				((UnitIndex += 1))
				Value=$((Value / Divisor))
			done

			case "$Req" in
			size)
				printf '%s%s' "$Value" "${Units[$UnitIndex]}"
				;;
			size+format)
				printf '%s_%s' "$Value" "${Units[$UnitIndex]}"
				;;
			format)
				printf '%s' "${Units[$UnitIndex]}"
				;;
			format+size)
				printf '%s/%s' "${Units[$UnitIndex]}" "$Value"
				;;
			esac
		fi
		;;

	# Filesystem timestamps.
	created)
		Get_File_Creation_Time "$File"
		;;
	modified)
		Get_File_Modification_Time "$File"
		;;
	accessed)
		Get_File_Access_Time "$File"
		;;

	# Checksums. Some algorithms require optional external programs.
	md5 | md5sum)
		Get_MD5Sum "$File"
		;;
	sha)
		Get_SHA_Keys shasum "$File"
		;;
	sha1 | sha224 | sha256 | sha384 | sha512)
		Get_SHA_Keys "${Req}sum" "$File"
		;;
	shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum)
		Get_SHA_Keys "$Req" "$File"
		;;

	# random returns one Bash random value; randomN concatenates N values.
	random*)
		local Count=${Req#random}

		if [[ -z "$Count" ]]; then
			printf '%s' "$RANDOM"
		elif [[ "$Count" =~ ^[0-9]+$ ]]; then
			while ((Count > 0)); do
				printf '%s' "$RANDOM"
				((Count -= 1))
			done
		else
			printf 'ERROR'
			return 1
		fi
		;;

	# Unknown keywords produce an explicit error marker.
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}

Parse_Arguments() {
	local Argument

	for Argument in "$@"; do
		case "${Argument,,}" in
		# Operation modes: only one mode should normally be supplied.
		--copy) Mode="copy" ;;
		--move) Mode="move" ;;
		--delete) Mode="delete" ;;
		--remove) Mode="remove" ;;
		--trash) Mode="trash" ;;
		--shred) Mode="shred" ;;
		--mode=*)
			Mode=${Argument#*=}
			Mode=${Mode,,}
			;;

		# Processing and filtering options.
		--type=*) Type=${Argument#*=} ;;
		--recursive) Recursive="yes" ;;
		--pause=*) Pause=${Argument#*=} ;;

		# Destination and naming options.
		--dirs=*) Dirs=${Argument#*=} ;;
		--subdirs=*) SubDirs=${Argument#*=} ;;
		--rename=*) Rename=${Argument#*=} ;;
		--extension=*) Extension=${Argument#*=} ;;
		--title) Title="yes" ;;
		--replace) Replace="yes" ;;

		# Retained legacy switches. They are parsed but not implemented.
		--jobs=*) MAX_JOBS=${Argument#*=} ;;
		--compare) Compare="yes" ;;

		# Any argument not recognized as an option is treated as a path.
		--*)
			printf '%bWARNING:%b Unknown option: %s (ignored)\n' \
				"$YELLOW" "$RESET" "$Argument"
			;;
		*)
			InputItems+=("$Argument")
			;;
		esac
	done
}

Validate_Options() {
	case "$Mode" in
	"" | copy | move | delete | remove | trash | shred) ;;
	*)
		printf '%bERROR:%b Unsupported mode: %s\n' "$RED" "$RESET" "$Mode"
		return 1
		;;
	esac

	# Validate the pause value as a non-negative numeric duration.
	if [[ -n "$Pause" && ! "$Pause" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
		printf '%bERROR:%b --pause must be a non-negative number of seconds.\n' \
			"$RED" "$RESET"
		return 1
	fi

	# These options existed in the original parser but have no active behavior.
	[[ -n "$MAX_JOBS" && "$MAX_JOBS" != 4 ]] &&
		printf '%bWARNING:%b --jobs is currently not implemented.\n' "$YELLOW" "$RESET"

	[[ "$Compare" == "yes" ]] &&
		printf '%bWARNING:%b --compare is currently not implemented.\n' "$YELLOW" "$RESET"

	# Check mode-specific optional programs only when those modes are requested.
	if [[ "$Mode" == "trash" ]] && ! command -v trash-put >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=trash requires trash-put (trash-cli).\n' "$RED" "$RESET"
		return 1
	fi

	if [[ "$Mode" == "shred" ]] && ! command -v shred >/dev/null 2>&1; then
		printf '%bERROR:%b --mode=shred requires shred (coreutils).\n' "$RED" "$RESET"
		return 1
	fi
}

Perform_Action() {
	local SourcePath=$1
	local TargetPath=$2
	local SourceReal TargetReal

	# Dry-run mode is the default and never modifies the filesystem.
	if [[ -z "$Mode" ]]; then
		printf '%bTEST:%b %s -> %s\n' "$BLUE" "$RESET" "$SourcePath" "$TargetPath"
		return 0
	fi

	# Ensure the destination directory exists for copy and move operations.
	if [[ "$Mode" == "copy" || "$Mode" == "move" ]]; then
		if ! mkdir -p -- "${TargetPath%/*}"; then
			printf '%bERROR:%b Could not create destination directory.\n' "$RED" "$RESET"
			return 1
		fi
	fi

	# Resolve both paths before destructive operations to avoid acting on the
	# source file by accident when source and destination refer to the same file.
	if [[ -e "$TargetPath" ]]; then
		SourceReal=$(realpath -m -- "$SourcePath" 2>/dev/null)
		TargetReal=$(realpath -m -- "$TargetPath" 2>/dev/null)

		if [[ -n "$SourceReal" && "$SourceReal" == "$TargetReal" ]]; then
			case "$Mode" in
			delete | remove | trash | shred)
				printf '%bERROR:%b Source and target are the same file; refusing destructive action: %s\n' \
					"$RED" "$RESET" "$SourcePath"
				return 1
				;;
			esac
		fi
	fi

	# Execute the selected action. -- prevents paths beginning with "-" from
	# being interpreted as command-line options by the external utility.
	case "$Mode" in
	copy)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			printf '%bERROR:%b Destination already exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		fi
		cp -v -f -- "$SourcePath" "$TargetPath"
		;;
	move)
		if [[ -e "$TargetPath" && "$Replace" != "yes" ]]; then
			printf '%bERROR:%b Destination already exists: %s\n' "$RED" "$RESET" "$TargetPath"
			return 1
		fi
		mv -v -f -- "$SourcePath" "$TargetPath"
		;;
	delete | remove)
		if [[ -e "$TargetPath" ]]; then
			rm -v -f -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	trash)
		if [[ -e "$TargetPath" ]]; then
			trash-put -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	shred)
		if [[ -e "$TargetPath" ]]; then
			shred -u -n 1 -- "$TargetPath"
		else
			printf 'File not found: %s\n' "$TargetPath"
			return 1
		fi
		;;
	esac
}

Sort() {
	local Item
	local Directory
	local FileName FileExtension NewName
	local DestinationDir SubDirectory TargetPath
	local TemporaryName
	local -a Children

	# Increase recursion depth and initialize this level's progress counters.
	((Current += 1))
	Total[$Current]=$#
	Counter[$Current]=0

	for Item in "$@"; do
		# Update progress for the current recursion level.
		((Counter[$Current] += 1))
		printf 'PROGRESS'
		local Level
		for ((Level = 1; Level <= Current; Level++)); do
			printf ' ~ [%d]=%d/%d' "$Level" "${Counter[$Level]}" "${Total[$Level]}"
		done
		printf '\n'

		# Skip paths that do not exist, including broken symbolic links.
		if [[ ! -e "$Item" && ! -L "$Item" ]]; then
			printf 'SKIP: Does not exist: %s\n' "$Item"
			continue
		fi

		# Symbolic links are deliberately skipped to avoid following links
		# outside the requested directory tree or processing the same target twice.
		if [[ -L "$Item" ]]; then
			printf 'SKIP: Symbolic link: %s\n' "$Item"
			continue
		fi

		# Directory handling: recurse only when the user supplied --recursive.
		if [[ -d "$Item" ]]; then
			Draw_Line '='
			if [[ "$Recursive" == "yes" ]]; then
				printf '%bDIR:%b %s\n' "$BLUE" "$RESET" "$Item"
				Draw_Line '>'

				# Expand the directory's contents, including hidden files.
				# nullglob ensures an empty directory produces an empty array.
				Children=("$Item"/*)

				if ((${#Children[@]} > 0)); then
					Sort "${Children[@]}"
				fi

				Draw_Line '<'

				# After a move operation, remove the source directory only if
				# it is now empty. rmdir safely refuses non-empty directories.
				if [[ "$Mode" == "move" ]]; then
					rmdir -v -- "$Item" 2>&1
				fi
			else
				printf '%bDIR:%b Skipping (use --recursive): %s\n' \
					"$YELLOW" "$RESET" "$Item"
			fi
			Draw_Line '='
			continue
		fi

		# Ignore special filesystem objects; this organizer handles regular files.
		if [[ ! -f "$Item" ]]; then
			printf '%bSKIP:%b Not a regular file: %s\n' "$YELLOW" "$RESET" "$Item"
			continue
		fi

		# Start processing a regular file.
		Draw_Line '-'
		printf '%bFILE:%b %s\n' "$GREEN" "$RESET" "$Item"

		# Read MIME information once and split it into major and minor parts.
		MIME=$(Get_MIME "$Item")
		MIMEMain=${MIME%%/*}
		MIMESub=${MIME#*/}

		printf '%bMIME:%b %s\n' "$YELLOW" "$RESET" "$MIME"

		# If --type was provided, the requested text must occur in the MIME type.
		if [[ -n "$Type" && "${MIME,,}" != *"${Type,,}"* ]]; then
			printf '%bSKIP:%b MIME type does not match --type=%s\n' \
				"$YELLOW" "$RESET" "$Type"
			Draw_Line '-'
			continue
		fi

		# --------------------------------------------------------------------
		# 10a. Build the destination directory
		# --------------------------------------------------------------------

		# --dirs selects the primary directory component. Without it, use the
		# source file's current parent directory.
		if [[ -n "$Dirs" ]]; then
			DestinationDir=$(Resolve_Path_Segment "$Dirs" "$Item")
		else
			DestinationDir=${Item%/*}
			[[ "$DestinationDir" == "$Item" ]] && DestinationDir="."
		fi

		# --subdirs adds one more level beneath the primary directory.
		SubDirectory=""
		if [[ -n "$SubDirs" ]]; then
			SubDirectory=$(Resolve_Path_Segment "$SubDirs" "$Item")
		fi

		# Assemble the final destination directory, avoiding empty components.
		if [[ -z "$DestinationDir" ]]; then
			DestinationDir="."
		fi
		if [[ -n "$SubDirectory" ]]; then
			DestinationDir="${DestinationDir%/}/$SubDirectory"
		fi

		printf '%bTARGET DIR:%b %s\n' "$YELLOW" "$RESET" "$DestinationDir"

		# --------------------------------------------------------------------
		# 10b. Build the destination filename
		# --------------------------------------------------------------------

		# Start with the original basename; --rename can replace it with a
		# dynamic value such as sha256sum, year or random.
		FileName=$(Get_File_Name "$Item")
		if [[ -n "$Rename" ]]; then
			TemporaryName=$(Resolve_Path_Segment "$Rename" "$Item")
			[[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]] &&
				FileName=$TemporaryName
		fi

		# --title takes precedence over --rename when metadata is available.
		if [[ "$Title" == "yes" ]]; then
			TemporaryName=""
			case "${MIMEMain,,}" in
			application)
				TemporaryName=$(Get_Doc_Title "$Item")
				;;
			image)
				TemporaryName=$(Get_Image_Meta "$Item")
				;;
			audio)
				TemporaryName=$(Get_Audio_Info "$Item")
				;;
			video)
				TemporaryName=$(Get_Video_Title "$Item")
				;;
			esac

			# Do not replace the filename with an empty or error result.
			if [[ -n "$TemporaryName" && "$TemporaryName" != "ERROR" ]]; then
				FileName=$TemporaryName
			fi
		fi

		# Use the original extension unless --extension supplied a replacement.
		if [[ -n "$Extension" ]]; then
			FileExtension=$(Resolve_Path_Segment "$Extension" "$Item")
		else
			FileExtension=$(Get_File_Ext "$Item")
		fi

		# Normalize the extension and replace a MIME slash with a dot.
		FileExtension=${FileExtension,,}
		FileExtension=${FileExtension//\//.}

		# Assemble the destination filename. A file with no extension is kept
		# extensionless instead of receiving an artificial trailing dot.
		if [[ -n "$FileExtension" && "$FileExtension" != "$Item" ]]; then
			NewName="$FileName.$FileExtension"
		else
			NewName=$FileName
		fi

		TargetPath="${DestinationDir%/}/$NewName"
		[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"

		# --------------------------------------------------------------------
		# 10c. Avoid accidental name collisions for copy/move
		# --------------------------------------------------------------------

		# When --replace is absent, find the first unused "name-(N).ext".
		# This check applies only to copy and move, not destructive modes.
		if [[ "$Mode" == "copy" || "$Mode" == "move" ]] &&
			[[ "$Replace" != "yes" ]]; then
			local CollisionIndex=0
			local TargetBase=$FileName
			local TargetExtension=""

			if [[ "$NewName" == *.* ]]; then
				TargetExtension=".${NewName##*.}"
			fi

			while [[ -e "$TargetPath" ]]; do
				((CollisionIndex += 1))
				NewName="${TargetBase}-(${CollisionIndex})${TargetExtension}"
				TargetPath="${DestinationDir%/}/$NewName"
				[[ "$DestinationDir" == "." ]] && TargetPath="./$NewName"
			done
		fi

		printf '%bNEW NAME:%b %s\n' "$YELLOW" "$RESET" "$NewName"
		printf '%bTARGET:%b %s\n' "$YELLOW" "$RESET" "$TargetPath"

		# --------------------------------------------------------------------
		# 10d. Perform the requested action, or show a dry-run preview
		# --------------------------------------------------------------------

		Perform_Action "$Item" "$TargetPath"

		# Optional pause between files, useful when watching terminal output.
		if [[ -n "$Pause" ]]; then
			sleep "$Pause"
		fi

		Draw_Line '-'
	done

	# Decrease the recursion depth when this directory level has completed.
	((Current -= 1))
}

Show_Help() {
	Draw_Line '━'

	cat <<'EOF'
Sort.sh v2.1 - Media-Intelligent File Organizer
Organizes files using MIME information, filesystem timestamps and metadata.

USAGE
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

  With no operation mode, the script performs a dry run and only displays
  the planned destination. Files are not changed unless a mode is selected.

OPERATION MODES
  --mode=copy       Copy files to the calculated destination.
  --mode=move       Move files to the calculated destination.
  --mode=delete     Permanently delete the calculated destination file.
  --mode=remove     Alias for --mode=delete.
  --mode=trash      Send the calculated destination file to desktop trash.
  --mode=shred      Run shred -u -n 1 on the calculated destination file.

  Short forms:
  --copy            Same as --mode=copy.
  --move            Same as --mode=move.
  --delete          Same as --mode=delete.
  --remove          Same as --mode=remove.
  --trash           Same as --mode=trash.
  --shred           Same as --mode=shred.

  IMPORTANT:
  delete/remove/trash/shred operate on the calculated TARGET path, not
  automatically on the original source path. If source and target resolve
  to the same file, destructive operations are refused. Review the TARGET
  output carefully before selecting a destructive mode.

FILTERING AND PROCESSING
  --type=VALUE      Process only files whose MIME type contains VALUE.
                    Examples: image, video, audio, pdf, application.
  --recursive       Process files inside supplied directories, including
                    nested directories and hidden files.
  --pause=SECONDS   Wait for the specified number of seconds after each file.

DESTINATION AND NAMING
  --dirs=VALUE      Set the primary destination directory component.
  --subdirs=VALUE   Add a directory component beneath the primary directory.
  --rename=VALUE    Generate a filename (without extension) from VALUE.
  --extension=VALUE Generate the extension from VALUE.
  --title           Try to create the filename from embedded metadata:
                    application: attempts to read a PDF /Title entry
                    image:      uses date_time_original, then filesystem time
                    audio:      combines Artist, Album and Title tags
                    video:      combines Artist and Title tags
                    other:      keeps the original filename
  --replace         Allow copy/move to overwrite an existing destination.
                    Without it, a unique name such as photo-(1).jpg is used.

DYNAMIC VALUES
  Values below can be used with --dirs, --subdirs, --rename and --extension.
  Keywords are case-insensitive.

  DATE AND FILE TIMES
    year              Birth-time year (YYYY); 0000 if unavailable.
    month             Birth-time month (MM); 00 if unavailable.
    day               Birth-time day (DD); 00 if unavailable.
    year+month        Year/month path (YYYY/MM).
    year+month+day    Year/month/day path (YYYY/MM/DD).
    created           Filesystem creation-time string.
    modified          Last modification-time string.
    accessed          Last access-time string.

  FILE IDENTITY
    extension         Original extension.
    mime              Full MIME type, e.g. IMAGE/JPEG.
    mime-main         MIME major type, e.g. IMAGE or VIDEO.
    mime-sub          MIME subtype, e.g. JPEG, MP4 or PDF.
    md5 / md5sum      MD5 checksum.
    sha               SHA checksum using shasum.
    sha1              SHA-1 checksum using sha1sum.
    sha224            SHA-224 checksum using sha224sum.
    sha256            SHA-256 checksum using sha256sum.
    sha384            SHA-384 checksum using sha384sum.
    sha512            SHA-512 checksum using sha512sum.
    shasum            Checksum using shasum.
    sha1deep          Checksum using sha1deep.
    sha256deep        Checksum using sha256deep.
    sha1sum           Checksum using sha1sum.
    sha224sum         Checksum using sha224sum.
    sha256sum         Checksum using sha256sum.
    sha384sum         Checksum using sha384sum.
    sha512sum         Checksum using sha512sum.
    random            One Bash-generated random number.
    randomN           N concatenated random values, e.g. random3.

  SIZE AND MEDIA DIMENSIONS
    size              Images/videos: width x height (e.g. 1920x1080).
                      Other files: decimal file-size unit (B, KB, MB, GB, TB).
    format            Images/videos: resolution tier and orientation.
                      Other files: decimal unit name (Byte, Kilo, Mega, etc.).
    size+format       Images/videos: tier/orientation plus dimensions.
                      Other files: binary unit (B, KiB, MiB, GiB, TiB).
    format+size       Images/videos: tier/orientation plus dimensions.
                      Other files: decimal unit name followed by the value.

  Resolution tiers use the larger dimension:
    TINY, MINI, SMALLER, SMALL, MEDIUM, BIG, BIGGER, HUGE.
  Orientation is SQUARE, WIDE or HIGH.

EXAMPLES
  Preview images grouped by MIME category:
    Sort.sh --dirs=mime-main --type=image ./Downloads/*

  Move videos into year/month folders and use metadata titles:
    Sort.sh --mode=move --dirs=year+month --title --type=video ./Videos/*

  Copy images and use their SHA-256 checksum as the filename:
    Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg

  Organize PDF files by extension and size-unit label:
    Sort.sh --mode=move --dirs=extension --subdirs=format *.pdf

  Preview a destination filename based on the original extension:
    Sort.sh --dirs=mime-main --rename=extension ./Downloads/*

DEPENDENCIES
  Required: Bash, file, coreutils, grep, sed, ffprobe (FFmpeg),
            identify (ImageMagick), and tput (ncurses/terminfo).
  Optional: trash-put for trash mode; shred for shred mode; additional
            checksum programs for the matching checksum keywords.

NOTES AND LIMITATIONS
  * Requires Bash with associative arrays and modern [[ ... ]] syntax.
  * File birth/creation times depend on filesystem support.
  * PDF title extraction is a simple text search, not a complete PDF parser.
  * Metadata extraction is best-effort and depends on the media format.
  * --jobs and --compare are accepted for compatibility but are not implemented.
  * shred cannot guarantee secure erasure on SSDs, snapshots, journals,
    copy-on-write filesystems or storage devices with wear levelling.
  * Always perform a dry run before using move, delete, trash or shred.
EOF

	Draw_Line '━'
}

# Run directly (not when sourced) — closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
