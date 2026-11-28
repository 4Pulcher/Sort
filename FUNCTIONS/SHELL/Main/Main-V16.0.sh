Main() {
	# No arguments at all: show the short usage
	if [ $# -eq 0 ]; then
		Usage
		return 0
	fi

	Parse_Arguments "$@"

	# Init-system: propose one batch install for the optional media tools
	if [ "$Quiet" -eq 0 ]; then
		Deps_Init identify ffprobe || true
	fi

	# The array of files to treat, built before any work starts
	Collect_Files

	if [ "${#Targets[@]}" -eq 0 ]; then
		Print_Warning 'Nothing to treat.'
		return 1
	fi

	[ "$Quiet" -eq 1 ] || Print_Header "Sorting ${#Targets[@]} file(s) - mode: $Modus, jobs: $Max_Jobs"

	Run_Threads "${Targets[@]}"
}
