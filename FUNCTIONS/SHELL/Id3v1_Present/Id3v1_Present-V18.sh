Id3v1_Present() {
	local File=$1 Tag

	[ -r "$File" ] || return 1
	Tag=$(tail -c 128 -- "$File" 2>/dev/null | head -c 3)
	[ "$Tag" = 'TAG' ]
}
