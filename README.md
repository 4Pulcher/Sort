## Hey,

# !! BE CAREFULL WITH THIS SCRIPT !!
I strongly advise you to understand the scripts content before you use it!

Offen, when recovering files with 'PhotoRec' or something similar,
You end-up with a bunch of 'folders and files' mixed up!

That's when I prefer this script to sort things out,
'With ease'..

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

