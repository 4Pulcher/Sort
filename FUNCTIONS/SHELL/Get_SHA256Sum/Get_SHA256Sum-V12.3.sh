Get_SHA256Sum() {
	sha256sum -b -- "$1" 2>/dev/null | cut -d' ' -f1
}
