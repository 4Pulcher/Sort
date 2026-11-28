Get_MD5Sum() {
	local File=$1
	local Sum

	Sum=$(md5sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}
