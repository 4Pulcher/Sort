Parse_Arguments() {
	local Argument

	for Argument in "$@"; do
		case "${Argument,,}" in
		# Shorthand operational modes
		--copy) Mode="copy" ;;
		--move) Mode="move" ;;
		--delete) Mode="delete" ;;
		--remove) Mode="remove" ;;
		--trash) Mode="trash" ;;
		--shred) Mode="shred" ;;

		# Explicit operational mode
		--mode=*)
			Mode=${Argument#*=}
			Mode=${Mode,,}
			;;

		# Filters & recursion
		--type=*) Type=${Argument#*=} ;;
		--recursive) Recursive="yes" ;;
		--pause=*) Pause=${Argument#*=} ;;

		# Path & filename templates
		--dirs=*) Dirs=${Argument#*=} ;;
		--subdirs=*) SubDirs=${Argument#*=} ;;
		--rename=*) Rename=${Argument#*=} ;;
		--extension=*) Extension=${Argument#*=} ;;
		--title) Title="yes" ;;
		--replace) Replace="yes" ;;

		# Legacy compatibility flags
		--jobs=*) MAX_JOBS=${Argument#*=} ;;
		--compare) Compare="yes" ;;

		# Catch unrecognized flags
		--*)
			printf '%bWARNING:%b Unknown option: %s (ignored)\n' \
				"$YELLOW" "$RESET" "$Argument"
			;;

		# Everything else is queued as a target file or directory
		*)
			InputItems+=("$Argument")
			;;
		esac
	done
}
