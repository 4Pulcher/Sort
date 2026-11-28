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
		--compare) Compare="yes" ;;
		--colors)
			ENABLE_COLORS="yes"
			BOLD="$_BOLD"
			BLUE="$_BLUE"
			CYAN="$_CYAN"
			GREEN="$_GREEN"
			RED="$_RED"
			YELLOW="$_YELLOW"
			DIM="$_DIM"
			RESET="$_RESET"
			;;
		--log)
			ENABLE_LOG="yes"
			local TodaysDate
			TodaysDate=$(date +%Y-%m-%d)
			LOG_FILE="./Sort ~ $TodaysDate.log"
			printf '=== Sort.sh v2.5 Log Started: %s ===\n' "$(date)" >"$LOG_FILE"
			;;
		--*)
			printf 'WARNING: Unknown option: %s (ignored)\n' "$Argument"
			;;
		*)
			InputItems+=("$Argument")
			;;
		esac
	done
}
