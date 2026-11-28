Id3v2_Tag_Size() {
	local File=$1 Bytes
	local B0 B1 B2 B3

	[ -r "$File" ] || return 1
	Id3v2_Present "$File" || return 1

	Bytes=$(head -c 10 -- "$File" 2>/dev/null | tail -c 4 | od -An -tu1 | tr -s ' \n' ' ')
	read -r B0 B1 B2 B3 <<<"$Bytes"
	[ -n "$B3" ] || return 1
	printf '%s' $(((B0 << 21) | (B1 << 14) | (B2 << 7) | B3))
}
