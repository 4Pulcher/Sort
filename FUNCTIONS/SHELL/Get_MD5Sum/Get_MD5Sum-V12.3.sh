Get_MD5Sum() {
	md5sum -b -- "$1" 2>/dev/null | cut -d' ' -f1
}
