Get_MIME() {
	file -b --mime-type -- "$1" 2>/dev/null
}
