Main() {
	# No arguments at all: show the short usage
	if [ $# -eq 0 ]; then
		Usage
		return 0
	fi

	Parse_Arguments "$@"

	# Init-system: one batch install proposal for the optional media tools
	# (exiftool joins when EXIF features are requested)
	if [ "$Quiet" -eq 0 ]; then
		if [ "$Use_EXIF" -eq 1 ] || [ "$Strip" -eq 1 ]; then
			Deps_Init identify ffprobe exiftool || true
		else
			Deps_Init identify ffprobe || true
		fi
	fi

	# The array of files to treat, built before any work starts
	Collect_Files

	if [ "${#Targets[@]}" -eq 0 ]; then
		Print_Warning 'Nothing to treat.'
		return 1
	fi

	if [ "$Quiet" -eq 0 ]; then
		Draw_Line '='
		Print_Header "Sorting ${#Targets[@]} file(s) - mode: $Modus, jobs: $Max_Jobs"
	fi

	Run_Threads "${Targets[@]}"
}
