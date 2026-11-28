File_Is_Empty() {
	[ -f "$1" ] && [ ! -s "$1" ]
}
