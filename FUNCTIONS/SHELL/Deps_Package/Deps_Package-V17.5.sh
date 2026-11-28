Deps_Package() {
	local Tool=${1,,}
	local Installer

	Installer=${2:-$(Deps_Installer)} || return 1

	case "$Tool:$Installer" in
	exiftool:apt-get | exiftool:apt) printf 'libimage-exiftool-perl' ;;
	exiftool:dnf | exiftool:yum) printf 'perl-Image-ExifTool' ;;
	exiftool:*) printf 'exiftool' ;;
	ffprobe:* | ffmpeg:* | ffplay:*) printf 'ffmpeg' ;;
	identify:* | magick:* | convert:* | compare:*) printf 'imagemagick' ;;
	file:*) printf 'file' ;;
	tar:* | gzip:* | gunzip:* | bzip2:* | bunzip2:* | xz:* | unxz:* | zstd:* | unzip:* | zip:*)
		printf '%s' "$Tool"
		;;
	7z:apt-get | 7z:apt) printf 'p7zip-full' ;;
	7z:*) printf 'p7zip' ;;
	unrar:*) printf 'unrar' ;;
	trash-put:* | trash:*) printf 'trash-cli' ;;
	md5sum:* | sha1sum:* | sha224sum:* | sha256sum:* | sha384sum:* | sha512sum:* | b2sum:* | cksum:* | cmp:* | stat:* | timeout:* | od:* | wc:* | du:* | head:* | tail:*)
		printf 'coreutils'
		;;
	*) return 1 ;;
	esac
}
