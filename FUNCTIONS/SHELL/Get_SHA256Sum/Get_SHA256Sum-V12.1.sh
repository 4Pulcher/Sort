Get_SHA256Sum() {
	local File=$1
	sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1
}
