## Hey,

# !! BE CAREFULL WITH THIS SCRIPT !!
I strongly advise you to understand the scripts content before you use it!

"Offen, when recovering files with 'PhotoRec' or something similar,
You end-up with a bunch of 'folders and files' mixed up!

That's when I prefer this script to sort things out,
'With ease'.."

NB/If you want more options, please give a sign!

# Exp1)

cd Pictures/Wallpapers ;
~/BASH/Sort.sh --Move --Recursive --Replace --Rename=random --SubDirs=size *

"This moves all files in Wallpapers - renaming to random-numbers - in to WorkingDirectory/WIDTHxHEIGHT - recursively!"

# Exp2)

	cd Pictures/Wallpapers ;
	~/BASH/Sort.sh --Move --Recursive --Replace --Rename=sha256sum --Dirs=mime-sub --SubDirs=format+size .

"This moves all files in WorkingDirectory - renaming to SHA256SUM of the files as filename - in to WorkingDirectory/MIME-TYPE/MIME-SUBTYPE/FORMAT/FORMAT2/WIDTHxHEIGHT - recursively!"

# Exp3)

	cd Pictures/Sorted ;
	~/BASH/Sort.sh --Copy --Recursive --Replace --Dirs=mime-sub --SubDirs=format+size ~/Pictures/2Sort

"This copies all files from the directory $HOME/Pictures/2Sort - keeping filenames - in to WorkingDirectory/MIME-SUBTYPE/FORMAT/FORMAT2/WIDTHxHEIGTH - recursively!"

# Exp4)

	cd Pictures/2Sort ;
	~/BASH/Sort.sh --Remove --Recursive --Dirs=mime-sub --SubDirs=format+size ~/Pictures/Sorted

"This removes all files in WorkingDirectory - all files with simalar names - from the $HOME/Pictures/Sorted/FORMAT/FORMAT2/WIDTHxHEIGHT - recursively!"

!! You can use 'size' option with other files - other than pictures - where FORMAT and SIZE changes (exp '../MegaByte/5/' or '../5GiB/') !!

# Under developpement!

USAGE: EOF
	📂	Sort.sh v2.1 | Media-Intelligent File Organizer
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
							Developed by: Ali_ISIN

	SYNTAX:
		Sort.sh [OPTIONS] [FILE/DIR LIST]

	OPERATIONAL MODES: (Choose one)
	--mode=copy       Duplicates files to the new destination.
	--mode=move       Relocates files (deletes source after success).
	--mode=remove     Deletes the target files permanently (moves to trash).

	FILTERS & BEHAVIOR:
	--type=VALUE      Filter by MIME (e.g., 'image', 'video', 'pdf').
	--recursive       Process subdirectories found in the list.
	--replace         Overwrite existing files (Be careful!).
	--title Behavior by File Type:
		VIDEO:   Extracts internal 'Title' tag.
		AUDIO:   Extracts 'Artist - Title' tags.
		IMAGE:   Extracts Camera Make & Model.
		PDF:     Extracts internal Document Title.
		OTHER:   Falls back to SHA256 content hash.
	--pause=SEC       Wait X seconds between each file action.

	ORGANIZATION SETTINGS:
	--dirs=OPT        Primary directory structure.
	--subdirs=OPT     Secondary directory structure.
	--rename=OPT      Override filename with a dynamic value.
	--extension=OPT   Override file extension with a dynamic value.

	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	DYNAMIC OPTION VALUES (Used for --dirs, --subdirs, --rename):

	DATE & TIME:
		year, month, day  Standard date parts (YYYY, MM, DD).
		year+month        Folder structure: YYYY/MM.
		year+month+day    Folder structure: YYYY/MM/DD.
		created           Full creation timestamp (if supported).
		modified          Full modification timestamp.
		accessed          Last access timestamp.

	MIME & IDENTITY:
		extension         File extension (UPPERCASE for folders).
		mime-main         MIME Category (IMAGE, VIDEO, APPLICATION).
		mime-sub          MIME Subtype (PNG, MP4, PDF).
		sha256sum         Unique 64-character hash of file content.
		random            Randomized numeric string.

	SMART SIZE (Context Aware):
		size              Media: Resolution (1920x1080) | Files: Size (45MB).
		format            Media: Tier (BIG/WIDE)        | Files: Label (MegaByte).

	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	EXAMPLES:

	# Organize videos by Title and put them in folders by Category:
	Sort.sh --mode=move --dirs=mime-main --title ./Downloads/*

	# Rename all images to their SHA256 hash and sort by year:
	Sort.sh --mode=copy --dirs=year --rename=sha256sum *.jpg

	# Detailed sorting of documents by size labels:
	Sort.sh --mode=move --dirs=extension --subdirs=format+size *.pdf
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
