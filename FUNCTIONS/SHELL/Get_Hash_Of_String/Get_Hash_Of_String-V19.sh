Get_Hash_Of_String() {
	local Algo=${1,,}
	local String=$2
	local Sum

	[ -n "$String" ] || return 1

	case "$Algo" in
	md5)
		command -v md5sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | md5sum)
		;;
	sha1)
		command -v sha1sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha1sum)
		;;
	sha224)
		command -v sha224sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha224sum)
		;;
	sha256)
		command -v sha256sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha256sum)
		;;
	sha384)
		command -v sha384sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha384sum)
		;;
	sha512)
		command -v sha512sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | sha512sum)
		;;
	b2 | blake2)
		command -v b2sum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | b2sum)
		;;
	crc32 | cksum)
		command -v cksum >/dev/null || return 127
		Sum=$(printf '%s' "$String" | cksum)
		;;
	*) return 1 ;;
	esac

	printf '%s' "${Sum%% *}"
}
