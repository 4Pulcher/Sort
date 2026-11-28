#!/bin/bash

###############################################################################
#                                                                             #
# Script  : Sort-V15.0.sh                                                     #
# Version : 15.0                                                              #
# Desc    : Modular file organizer (FUNCTIONS library)                        #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################
# lib/sort_engine.sh - Content-based sorting & deduplication

# Sort_File_By_MIME: sort file by mime
function Sort_File_By_MIME {
	local src="$1"
	local dest_dir="$2"
	if [[ ! -f "$src" ]]; then return 1; fi

	local mime_main mime_sub filename
	mime_main=$(file -b --mime-type "$src" | cut -d/ -f1)
	mime_sub=$(file -b --mime-type "$src" | cut -d/ -f2-)
	filename=$(basename "$src")

	local target="$dest_dir/$mime_main/$mime_sub"
	mkdir -p "$target"
	cp "$src" "$target/$filename"
}

# Get_File_SHA256: get file sha256
function Get_File_SHA256 {
	sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

echo "Thanks for using HEjder scripts!"
