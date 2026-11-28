Get_MD5Sum() {
	local File=$1
	md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1
}
