Id3v2_Major() {
	local Ver

	[ -r "$1" ] || return 1
	Id3v2_Present "$1" || return 1
	Ver=$(head -c 4 -- "$1" 2>/dev/null | tail -c 1 | od -An -tu1 | tr -d ' ')
	[ -n "$Ver" ] && printf '%s' "$Ver"
}
