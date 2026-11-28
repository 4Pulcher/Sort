Get_MIME_By_Magic() {
	local File=$1
	local Hex Sub

	Hex=$(Get_Magic_Bytes "$File" 16) || return $?
	Hex=${Hex// /}

	case "$Hex" in
	ffd8ff*) printf 'image/jpeg' ;;
	89504e47*) printf 'image/png' ;;
	47494638*) printf 'image/gif' ;;
	424d*) printf 'image/bmp' ;;
	25504446*) printf 'application/pdf' ;;
	504b03* | 504b05* | 504b07*) printf 'application/zip' ;;
	1f8b*) printf 'application/gzip' ;;
	425a68*) printf 'application/x-bzip2' ;;
	fd377a585a00*) printf 'application/x-xz' ;;
	377abcaf271c*) printf 'application/x-7z-compressed' ;;
	526172211a07*) printf 'application/vnd.rar' ;;
	7f454c46*) printf 'application/x-elf' ;;
	4d5a*) printf 'application/x-dosexec' ;;
	0061736d*) printf 'application/wasm' ;;
	53514c697465*) printf 'application/vnd.sqlite3' ;;
	494433*) printf 'audio/mpeg' ;;
	fffb* | fff3* | fff9* | ffa*) printf 'audio/mpeg' ;;
	4f676753*) printf 'audio/ogg' ;;
	664c6143*) printf 'audio/flac' ;;
	000001*) printf 'video/mpeg' ;;
	1a45dfa3*) printf 'video/x-matroska' ;;
	????????66747970*) printf 'video/mp4' ;;
	52494646*)
		# RIFF container: decide by the form type at offset 8.
		Sub=$(Get_Magic_Bytes "$File" 12) || return $?
		Sub=${Sub// /}
		case "$Sub" in
		????????????????57454250*) printf 'image/webp' ;;
		????????????????57415645*) printf 'audio/x-wav' ;;
		*) printf 'application/x-riff' ;;
		esac
		;;
	*) return 1 ;;
	esac
}
