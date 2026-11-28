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
