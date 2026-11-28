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
		--exif)
			Use_EXIF=1
			;;
		--strip)
			Strip=1
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
			printf 'Sort 16.1\n'
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
