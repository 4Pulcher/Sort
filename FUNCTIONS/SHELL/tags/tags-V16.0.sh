#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Script  : tags.sh                                                           #
# Version : 1.0                                                               #
# Desc    : Complete audio-tag toolkit - ID3v1 / ID3v2 readers in pure bash   #
# Author  : HEjder                                                            #
#                                                                             #
###############################################################################

# A complete, standalone bag of audio-tag tools: ID3v1 (last 128 bytes) and
# ID3v2 (v2.2 / v2.3 / v2.4 frames, latin-1 / UTF-16 / UTF-8 text) are read
# directly from the file bytes - no external tagger needed. Friendly getters
# (title, artist, album, year, genre, track) fall back to exiftool via the
# Exif_Field function when it is loaded and the file carries no ID3 tag
# (FLAC, Ogg, M4A, WMA...). Every function takes the file as its first
# argument, prints its result on stdout and returns non-zero on failure.

# ---------------------------------------------------------------------------
# ID3v1 - the fixed 128-byte tag at the end of the file
# ---------------------------------------------------------------------------

# True when the file ends with an ID3v1 tag.
# Id3v1_Present <file>
Id3v1_Present() {
	local File=$1 Tag

	[ -r "$File" ] || return 1
	Tag=$(tail -c 128 -- "$File" 2>/dev/null | head -c 3)
	[ "$Tag" = 'TAG' ]
}

# Genre name for an ID3v1 genre index (0-125: the 80 standard genres plus
# the Winamp extensions). Unknown or out-of-range indexes fail.
# Id3v1_Genre_Name <index>
Id3v1_Genre_Name() {
	local Idx=$1
	local -a G=(
		Blues 'Classic Rock' Country Dance Disco Funk Grunge 'Hip-Hop'
		Jazz Metal 'New Age' Oldies Other Pop 'R&B' Rap Reggae Rock Techno
		Industrial Alternative Ska 'Death Metal' Pranks Soundtrack
		'Euro-Techno' Ambient 'Trip-Hop' Vocal 'Jazz+Funk' Fusion Trance
		Classical Instrumental Acid House Game 'Sound Clip' Gospel Noise
		'Alternative Rock' Bass Soul Punk Space Meditation 'Instrumental Pop'
		'Instrumental Rock' Ethnic Gothic Darkwave 'Techno-Industrial'
		Electronic 'Pop-Folk' Eurodance Dream 'Southern Rock' Comedy Cult
		Gangsta 'Top 40' 'Christian Rap' 'Pop/Funk' Jungle 'Native US'
		Cabaret 'New Wave' Psychadelic Rave Showtunes Trailer 'Lo-Fi' Tribal
		'Acid Punk' 'Acid Jazz' Polka Retro Musical 'Rock & Roll' 'Hard Rock'
		Folk 'Folk-Rock' 'National Folk' Swing 'Fast Fusion' Bebob Latin
		Revival Celtic Bluegrass Avantgarde 'Gothic Rock' 'Progressive Rock'
		'Psychedelic Rock' 'Symphonic Rock' 'Slow Rock' 'Big Band' Chorus
		'Easy Listening' Acoustic Humour Speech Chanson Opera 'Chamber Music'
		Sonata Symphony 'Booty Bass' Primus 'Porn Groove' Satire 'Slow Jam'
		Club Tango Samba Folklore Ballad 'Power Ballad' 'Rhythmic Soul'
		Freestyle Duet 'Punk Rock' 'Drum Solo' 'A cappella' 'Euro-House'
		'Dance Hall'
	)

	[[ "$Idx" =~ ^[0-9]+$ ]] || return 1
	[ "$Idx" -lt "${#G[@]}" ] || return 1
	printf '%s' "${G[$Idx]}"
}

# One ID3v1 field by name: title artist album year comment track genre.
# Id3v1_Field <file> <field>
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

# ---------------------------------------------------------------------------
# ID3v2 - the frame-based tag at the start of the file (v2.2 / v2.3 / v2.4)
# ---------------------------------------------------------------------------

# True when the file starts with an ID3v2 tag.
# Id3v2_Present <file>
Id3v2_Present() {
	local File=$1 Magic

	[ -r "$File" ] || return 1
	Magic=$(head -c 3 -- "$File" 2>/dev/null)
	[ "$Magic" = 'ID3' ]
}

# ID3v2 major version (2, 3 or 4).
# Id3v2_Major <file>
Id3v2_Major() {
	local Ver

	[ -r "$1" ] || return 1
	Id3v2_Present "$1" || return 1
	Ver=$(head -c 4 -- "$1" 2>/dev/null | tail -c 1 | od -An -tu1 | tr -d ' ')
	[ -n "$Ver" ] && printf '%s' "$Ver"
}

# Total ID3v2 tag size in bytes (the synchsafe header size, header excluded).
# Id3v2_Tag_Size <file>
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

# One ID3v2 text frame by 4-character id (v2.2 files take 3-character ids).
# Id3v2_Field <file> <frame>
Id3v2_Field() {
	local File=$1 Frame=$2
	local Ver TagSize Off End Hdr FSize FID Bytes B0 B1 B2 B3 Data Enc

	[ -r "$File" ] || return 1
	Id3v2_Present "$File" || return 1

	Ver=$(Id3v2_Major "$File")
	TagSize=$(Id3v2_Tag_Size "$File") || return 1
	Off=10
	End=$((10 + TagSize))

	while [ "$Off" -lt "$End" ]; do
		if [ "$Ver" = '2' ]; then
			# v2.2: 3-char frame id, 3-byte big-endian size, no flags
			FID=$(dd if="$File" bs=1 skip="$Off" count=3 2>/dev/null)
			[[ "$FID" =~ ^[A-Z0-9]{3}$ ]] || break
			Bytes=$(dd if="$File" bs=1 skip=$((Off + 3)) count=3 2>/dev/null | od -An -tu1 | tr -s ' \n' ' ')
			read -r B0 B1 B2 <<<"$Bytes"
			[ -n "$B2" ] || break
			FSize=$(((B0 << 16) | (B1 << 8) | B2))
			Hdr=6
		else
			FID=$(dd if="$File" bs=1 skip="$Off" count=4 2>/dev/null)
			[[ "$FID" =~ ^[A-Z0-9]{4}$ ]] || break
			Bytes=$(dd if="$File" bs=1 skip=$((Off + 4)) count=4 2>/dev/null | od -An -tu1 | tr -s ' \n' ' ')
			read -r B0 B1 B2 B3 <<<"$Bytes"
			[ -n "$B3" ] || break
			if [ "$Ver" -ge 4 ]; then
				# v2.4: synchsafe size
				FSize=$(((B0 << 21) | (B1 << 14) | (B2 << 7) | B3))
			else
				# v2.3: plain big-endian size
				FSize=$(((B0 << 24) | (B1 << 16) | (B2 << 8) | B3))
			fi
			Hdr=10
		fi
		[ "$FSize" -gt 0 ] 2>/dev/null || break

		if [ "$FID" = "$Frame" ]; then
			# First payload byte is the text encoding:
			# 0 = latin-1, 1 = UTF-16 with BOM, 2 = UTF-16BE, 3 = UTF-8
			Enc=$(dd if="$File" bs=1 skip=$((Off + Hdr)) count=1 2>/dev/null | od -An -tu1 | tr -d ' ')
			case "$Enc" in
			1)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
					iconv -f UTF-16 -t UTF-8 2>/dev/null | tr -d '\0')
				if [ -z "$Data" ]; then
					Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
						iconv -f UTF-16LE -t UTF-8 2>/dev/null | tr -d '\0')
				fi
				;;
			2)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
					iconv -f UTF-16BE -t UTF-8 2>/dev/null | tr -d '\0')
				;;
			0)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null |
					iconv -f ISO-8859-1 -t UTF-8 2>/dev/null | tr -d '\0')
				;;
			*)
				Data=$(dd if="$File" bs=1 skip=$((Off + Hdr + 1)) count=$((FSize - 1)) 2>/dev/null | tr -d '\0')
				;;
			esac
			Data="${Data%"${Data##*[! ]}"}"
			[ -n "$Data" ] && printf '%s' "$Data"
			return $?
		fi

		Off=$((Off + Hdr + FSize))
	done

	return 1
}

# ---------------------------------------------------------------------------
# Friendly getters - v2 frames, then v1 fields, then exiftool when loaded
# ---------------------------------------------------------------------------

# One audio tag by friendly name: title artist album year genre track.
# Id3_Field <file> <field>
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

# Get_Audio_Title <file>
Get_Audio_Title() {
	local T

	T=$(Id3_Field "$1" title) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Title'
}

# Get_Audio_Artist <file>
Get_Audio_Artist() {
	local T

	T=$(Id3_Field "$1" artist) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Artist'
}

# Get_Audio_Album <file>
Get_Audio_Album() {
	local T

	T=$(Id3_Field "$1" album) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Album'
}

# Get_Audio_Year <file>
Get_Audio_Year() {
	local T

	T=$(Id3_Field "$1" year) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Year'
}

# Get_Audio_Genre <file>
Get_Audio_Genre() {
	local T

	T=$(Id3_Field "$1" genre) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Genre'
}

# Get_Audio_Track <file>
Get_Audio_Track() {
	local T

	T=$(Id3_Field "$1" track) && [ -n "$T" ] && {
		printf '%s' "$T"
		return 0
	}
	declare -F Exif_Field >/dev/null 2>&1 && Exif_Field "$1" 'Track'
}

# Composite directory for audio files: "<Artist>/<Year - Album>", empty
# levels skipped; components sanitized when Sanitize_Name is loaded.
# Get_Audio_Tags_Dir <file>
Get_Audio_Tags_Dir() {
	local File=$1 A Y Al Sub Out

	A=$(Get_Audio_Artist "$File" 2>/dev/null)
	Y=$(Get_Audio_Year "$File" 2>/dev/null)
	Al=$(Get_Audio_Album "$File" 2>/dev/null)

	if [ -n "$Y" ] && [ -n "$Al" ]; then
		Sub="$Y - $Al"
	else
		Sub="${Y}${Al}"
	fi

	Out="$A"
	[ -n "$Sub" ] && Out="${Out:+$Out/}$Sub"

	if [ -n "$Out" ] && declare -F Sanitize_Name >/dev/null 2>&1; then
		local -a Parts
		local P Result=''
		IFS='/' read -ra Parts <<<"$Out"
		for P in "${Parts[@]}"; do
			P=$(Sanitize_Name "$P")
			[ -n "$P" ] && Result="${Result:+$Result/}$P"
		done
		Out=$Result
	fi

	[ -n "$Out" ] && printf '%s' "$Out"
}

# Run directly (not when sourced) - closing phrase
[ "${BASH_SOURCE[0]}" = "$0" ] && echo "Thanks for using HEjder scripts!"
