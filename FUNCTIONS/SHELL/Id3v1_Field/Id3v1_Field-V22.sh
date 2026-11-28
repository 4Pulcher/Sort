Id3v1_Field() {
	local File=$1 Field=${2,,} Raw
	local Skip Count
	local B125 B126 Idx

	[ -r "$File" ] || return 1
	Id3v1_Present "$File" || return 1

	case "$Field" in
	title) Skip=3 Count=30 ;;
	artist) Skip=33 Count=30 ;;
	album) Skip=63 Count=30 ;;
	year) Skip=93 Count=4 ;;
	comment) Skip=97 Count=28 ;;
	track)
		# Track byte only valid when the comment zero-separator is there
		B125=$(tail -c 128 -- "$File" 2>/dev/null | tail -c 3 | head -c 1 | od -An -tu1 | tr -d ' ')
		B126=$(tail -c 128 -- "$File" 2>/dev/null | tail -c 2 | head -c 1 | od -An -tu1 | tr -d ' ')
		if [ "$B125" = '0' ] && [ -n "$B126" ] && [ "$B126" != '0' ]; then
			printf '%s' "$B126"
			return 0
		fi
		return 1
		;;
	genre)
		Idx=$(tail -c 128 -- "$File" 2>/dev/null | tail -c 1 | od -An -tu1 | tr -d ' ')
		if [ -n "$Idx" ] && Id3v1_Genre_Name "$Idx"; then
			return 0
		fi
		[ -n "$Idx" ] && [ "$Idx" != '255' ] && printf '%s' "$Idx"
		return 0
		;;
	*)
		return 1
		;;
	esac

	Raw=$(tail -c 128 -- "$File" 2>/dev/null | tail -c +$((Skip + 1)) | head -c "$Count" | tr -d '\0')
	Raw="${Raw%"${Raw##*[! ]}"}"
	[ -n "$Raw" ] && printf '%s' "$Raw"
}
