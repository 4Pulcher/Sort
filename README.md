Hey,

Offen, when recovering files with 'PhotoRec' or something similar,
You end-up with a bunch of 'folders and files' mixed up!

That's when I prefer this script to sort things out,
'With ease'..

NB/If you want more options, please give a sign!

Exp1)

cd Pictures/Wallpapers ;
~/BASH/Sort.sh --Move --Recursive --Replace --Rename=random --Dirs=mime-sub --SubDirs=size *

Exp2)

cd Pictures/Wallpapers ;
~/BASH/Sort.sh --Move --Recursive --Replace --Rename=sha256sum --Dirs=mime-sub --SubDirs=format+size .

Exp3)

cd Pictures/Sorted ;
~/BASH/Sort.sh --Copy --Recursive --Replace --Dirs=mime-sub --SubDirs=format+size ~/Pictures/2Sort

Exp4)

cd Pictures/2Sort ;
~/BASH/Sort.sh --Remove --Recursive --Dirs=mime-sub --SubDirs=format+size ~/Pictures/Sorted

Etc...

