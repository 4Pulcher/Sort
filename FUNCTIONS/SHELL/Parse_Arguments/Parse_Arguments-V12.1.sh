Parse_Arguments() {
	local Argument
	for Argument in "$@"; do
		case "${Argument,,}" in
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
		--type=*) Type=${Argument#*=} ;;
		--recursive) Recursive="yes" ;;
		--pause=*) Pause=${Argument#*=} ;;
		--dirs=*) Dirs=${Argument#*=} ;;
		--subdirs=*) SubDirs=${Argument#*=} ;;
		--rename=*) Rename=${Argument#*=} ;;
		--extension=*) Extension=${Argument#*=} ;;
		--title) Title="yes" ;;
		--replace) Replace="yes" ;;
		--jobs=*) MAX_JOBS=${Argument#*=} ;;
		--colors)
			# Enable ANSI color codes
			BOLD="$_BOLD"
			BLUE="$_BLUE"
			GREEN="$_GREEN"
			RED="$_RED"
			YELLOW="$_YELLOW"
			RESET="$_RESET"
			;;
		--log)
			ENABLE_LOG="yes"
			local TodaysDate
			TodaysDate=$(date +%Y-%m-%d)
			LOG_FILE="./Sort ~ $TodaysDate.log"
			# Initialize or touch log file
			printf '=== Sort.sh Log Started: %s ===\n' "$(date)" >"$LOG_FILE"
			;;
		--*) ;;
		*) InputItems+=("$Argument") ;;
		esac
	done
}
