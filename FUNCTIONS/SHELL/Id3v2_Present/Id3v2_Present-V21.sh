Id3v2_Present() {
	local File=$1 Magic

	[ -r "$File" ] || return 1
	Magic=$(head -c 3 -- "$File" 2>/dev/null)
	[ "$Magic" = 'ID3' ]
}
