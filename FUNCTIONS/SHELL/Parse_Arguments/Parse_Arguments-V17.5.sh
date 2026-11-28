Parse_Arguments() {
	local Item

	for Item in "$@"; do
		case "$Item" in
		--copy | --mode=copy)
			Modus='Copy'
			;;
		--move | --mode=move)
			Modus='Move'
			;;
		--remove | --delete | --mode=remove | --mode=delete)
			Modus='Remove'
			;;
		--trash | --mode=trash)
			Modus='Trash'
			;;
		--shred | --mode=shred)
			Modus='Shred'
			;;
		--mode=dummy | --mode=print)
			Modus='Print'
			;;
		--mode=*)
			Modus=${Item#--mode=}
			Modus=${Modus,,}
			Modus=${Modus^}
			;;
		--replace)
			Replace='Yes'
			;;
		--type=*)
			Type_Filter=${Item#--type=}
			;;
		--recursive)
			Recursive=1
			;;
		--hidden)
			Hidden=1
			;;
		--links)
			Links=1
			;;
		--pause=*)
			Pause=${Item#--pause=}
			;;
		--pause)
			Pause=1
			;;
		--target=*)
			Target_Dir=${Item#--target=}
			;;
		--dirs=*)
			Dirs_Spec=${Item#--dirs=}
			;;
		--subdirs=*)
			SubDirs_Spec=${Item#--subdirs=}
			;;
		--rename=*)
			Rename=${Item#--rename=}
			;;
		--extension=*)
			Append=${Item#--extension=}
			;;
		--title)
			Title_Mode=1
			;;
		--exif)
			Use_EXIF=1
			;;
		--strip)
			Strip=1
			;;
		--decompress)
			Decompress=1
			;;
		--colored | --colors)
			Color_Enable
			;;
		--quiet)
			Quiet=1
			;;
		--verbose)
			Quiet=0
			;;
		--stats)
			:
			;;
		--log=*)
			LogFile=${Item#--log=}
			;;
		--undo=*)
			UndoFile=${Item#--undo=}
			;;
		--undo)
			UndoFile="./sort_undo_$(date +%Y%m%d_%H%M%S).sh"
			;;
		--jobs=*)
			Max_Jobs=${Item#--jobs=}
			[ "$Max_Jobs" -ge 1 ] 2>/dev/null || Max_Jobs=1
			;;
		--magic)
			Magic_Mode=1
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
			printf 'Sort 17.5\n'
			exit 0
			;;
		--lang=*)
			Lang=${Item#--lang=}
			Lang=${Lang,,}
			;;
		--lang)
			Lang_List
			exit 0
			;;
		--)
			shift
			;;
		-*)
			Print_Warning "$(Tf 'Unknown option: %s (ignored)' "$Item")"
			;;
		*)
			Files+=("$Item")
			;;
		esac
	done
}
