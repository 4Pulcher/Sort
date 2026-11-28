Get_SHA_Keys() {
	local CommandName=$1 File=$2
	[[ ! -x "/usr/bin/$CommandName" ]] && {
		printf 'ERROR'
		return 1
	}
	/usr/bin/"$CommandName" -b -- "$File" 2>/dev/null | cut -d' ' -f1
}
