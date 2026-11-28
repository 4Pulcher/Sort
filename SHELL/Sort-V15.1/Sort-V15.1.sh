#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V15.1.sh                                                     #
# Version : 15.1                                                              #
# Desc    : Modular file organizer (FUNCTIONS library)                        #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# Break: break
function Break {
	IFS=$OIFS

	echo "End!"

	exit
}

trap Break INT

OIFS=$IFS
IFS=$'\n\b'

. ${0%/*}/../../FUNCTIONS/get_file.sh

. ${0%/*}/../../FUNCTIONS/get_mime.sh

. ${0%/*}/../../FUNCTIONS/get_image_exif.sh

. ${0%/*}/../../FUNCTIONS/get_video_exif.sh

# Sort_Recursive: sort recursive
function Sort_Recursive {
	[ $# -gt 0 ] && for Item in $@; do
		# Initiate
		if [ "$Item" == "--copy" ]; then
			Modus="Copy"

		elif [ "$Item" == "--move" ]; then
			Modus="Move"

		elif [ "$Item" == "--replace" ]; then
			Replace="Yes"

		elif [ "${Item:0:9}" == "--rename=" ]; then
			Rename="${Item:9}"

		elif [ "${Item:0:12}" == "--extension=" ]; then
			Append="${Item:12}"

		# Begin
		elif [ -d "$Item" ]; then
			printf "DIRECTORY: $Item\n"

			Sort_Recursive "$Item"/*

			### [ "$Modus" = "Move" ] && find "$Item" -empty -print -delete

		elif [ -f "$Item" ]; then
			printf "FILE: $Item\n"

			# Select a $Name
			if [ "$Rename" = "sha256sum" ]; then
				Name="$(get_file_sha256sum $Item)"
			elif [ "$Rename" = "long" ]; then
				Name="$(get_file_name_long $Item)"
			elif [ "$Rename" = "short" ]; then
				Name="$(get_file_name $Item)"
			else
				Name="$(get_file_folder $Item)_$(get_file_name $Item)"
			fi

			# Select an $Extension
			if [ "$Append" = "none" ]; then
				Extension=""
			elif [ "$Append" = "mime" ]; then
				Extension=".$(get_mime $Item | tr '/' '.')"
			elif [ "$Append" = "mime-sub" ]; then
				Extension=".$(get_mime_sub $Item)"
			else
				Extension=".$(get_file_extension $Item)"
			fi

			# Act according MIME-MAIN
			if [ $(get_mime_MAIN $Item) = "IMAGE" ]; then
				SubDir="$(get_image_size_Category $Item)/$(get_image_size_Form $Item)/$(get_image_dimension $Item)"
			elif [ $(get_mime_MAIN $Item) = "VIDEO" ]; then
				SubDir="$(get_video_dimention $Item)/$(get_video_duration $Item)"
			else
				SubDir="$(get_file_size_Category $Item)/$(get_file_size_short $Item)"
			fi

			# Generate new location
			NewDir="$(get_MIME $Item)/$SubDir"

			mkdir -v -p $NewDir

			# Generate new file-name
			New="$NewDir/$Name$Extension"

			[ ! "$Replace" = "Yes" ] && Count=0 && while [ -e "$New" ]; do
				((Count++))

				New="$NewDir/$Name~($Count)$Extension"
			done

			# Select an action
			if [ "${Item#./}" = "$New" ]; then
				printf "Skipping..\n"

			else
				if [ "$Modus" = "Copy" ]; then
					cp -v "$Item" "$New"
				elif [ "$Modus" = "Move" ]; then
					mv -v "$Item" "$New"
				else
					printf "$Item <=> $New\n"
				fi

			fi

			# Separate
			printf "\n"

		else
			# When an error
			printf "Unknown file type: $Item \!\!\n\n"

		fi
		# End
	done
}

if [ $# -gt 0 ]; then
	for Item in $@; do
		Sort_Recursive "$Item"
	done
else
	echo
	echo "${0#./}"
	echo
	echo "Version:	0.1"
	echo
	echo "Options:"
	echo
	echo "--copy	Copies the files"
	echo "--move	Moves the files"
	echo "--replace	Replaces on target"
	echo
	echo "--rename="
	echo "\"sha256sum\"	New filename from SHA256SUM"
	echo "\"long\"	New filename from \$directory_\$filename"
	echo "\"short\"	New filename from \$filename"
	echo "\"\"	New filename from \$folder_\$filename"
	echo
	echo "--extension="
	echo "\"none\"	No extension"
	echo "\"mime\"	Extensiont from \$MIME"
	echo "\"mime-sub\"	Extension from \$MIME-SUB"
	echo "\"\"	Extension from \$file (original)"
	echo
fi

Break

echo "Thanks for using HEjder scripts!"
