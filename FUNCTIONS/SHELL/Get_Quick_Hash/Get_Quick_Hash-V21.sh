Get_Quick_Hash() {
	local File=$1
	local Size Head Tail

	[ -f "$File" ] || return 1
	command -v sha256sum >/dev/null || return 127

	Size=$(stat -c '%s' -- "$File" 2>/dev/null)
	Head=$(head -c 1048576 -- "$File" 2>/dev/null | sha256sum | cut -d' ' -f1)
	Tail=$(tail -c 1048576 -- "$File" 2>/dev/null | sha256sum | cut -d' ' -f1)

	[ -n "$Head" ] && [ -n "$Tail" ] || return 1
	printf '%s-%s-%s' "$Size" "${Head:0:16}" "${Tail:0:16}"
}
