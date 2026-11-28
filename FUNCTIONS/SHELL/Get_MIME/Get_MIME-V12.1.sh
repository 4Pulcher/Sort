Get_MIME() {
	local File=$1
	file -b --mime-type -- "$File" 2>/dev/null
}
