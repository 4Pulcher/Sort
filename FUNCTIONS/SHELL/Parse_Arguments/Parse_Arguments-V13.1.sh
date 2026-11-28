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
