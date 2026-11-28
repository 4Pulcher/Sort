Magic_Nibbles() {
	head -c "$2" -- "$1" 2>/dev/null | od -An -v -tx1 | tr -d ' \n\t'
}
