Get_SHA256Sum() {
	local File=$1
	local Sum

	Sum=$(sha256sum -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}
