Get_SHA_Keys() {
	local CommandName=$1
	local File=$2
	local Sum
	[[ ! -x "/usr/bin/$CommandName" ]] && {
		printf 'ERROR'
		return 1
	}
	Sum=$("/usr/bin/$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1)
	printf '%s' "${Sum:-ERROR}"
}
