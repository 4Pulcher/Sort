Get_SHA_Keys() {
	local CommandName=$1
	local File=$2
	local Sum

	if [[ ! -x "/usr/bin/$CommandName" ]]; then
		printf 'ERROR'
		return 1
	fi

	Sum=$("/usr/bin/$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}
