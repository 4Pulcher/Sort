Id3_Field() {
	local File=$1 Field=${2,,} Frames F Data

	case "$Field" in
	title) Frames='TIT2 TT2' ;;
	artist) Frames='TPE1 TP1' ;;
	album) Frames='TALB TAL' ;;
	year) Frames='TDRC TYER TYE' ;;
	genre) Frames='TCON TCO' ;;
	track) Frames='TRCK TRK' ;;
	*)
		return 2
		;;
	esac

	for F in $Frames; do
		Data=$(Id3v2_Field "$File" "$F") && [ -n "$Data" ] && break
	done

	# ID3v1 fallback (also fixes v2.2 files when the frame walk failed)
	if [ -z "$Data" ]; then
		Data=$(Id3v1_Field "$File" "$Field")
	fi

	# Genre: "(17)" or plain "17" -> genre name
	if [ "$Field" = 'genre' ] && [ -n "$Data" ]; then
		if [[ "$Data" == \(*\) ]]; then
			Data="${Data#*(}"
			Data="${Data%%)*}"
		fi
		if [[ "$Data" =~ ^[0-9]+$ ]]; then
			Id3v1_Genre_Name "$Data" && return 0
		fi
	fi

	[ -n "$Data" ] && printf '%s' "$Data"
}
