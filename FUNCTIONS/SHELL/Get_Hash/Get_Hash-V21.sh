Get_Hash() {
	local Algo=${1,,}
	local File=$2

	case "$Algo" in
	md5) Get_MD5Sum "$File" ;;
	sha1) Get_SHA1Sum "$File" ;;
	sha224) Get_SHA224Sum "$File" ;;
	sha256) Get_SHA256Sum "$File" ;;
	sha384) Get_SHA384Sum "$File" ;;
	sha512) Get_SHA512Sum "$File" ;;
	b2 | blake2) Get_B2Sum "$File" ;;
	crc32 | cksum) Get_CRC32 "$File" ;;
	*)
		printf 'ERROR' >&2
		return 1
		;;
	esac
}
