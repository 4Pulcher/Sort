Resolve_Segment() {
	local Key=${1,,} File=$2 Mime=$3 Main=$4
	local Ts T TsB TsM WxH N Out Folder

	case "$Key" in
	# Date and file times
	year | month | day | year+month | year+month+day)
		Ts=$(Get_File_Timestamps "$File")
		TsB=${Ts%%|*}
		TsM=${Ts#*|}
		[[ -z "$TsB" || "$TsB" == '-'* ]] && Ts=$TsM || Ts=$TsB
		case "$Key" in
		year)
			Get_Cached_Date "$File" "$Ts" +%Y '0000'
			;;
		month)
			Get_Cached_Date "$File" "$Ts" +%m '00'
			;;
		day)
			Get_Cached_Date "$File" "$Ts" +%d '00'
			;;
		year+month)
			Get_Cached_Date "$File" "$Ts" +%Y/%m '0000/00'
			;;
		year+month+day)
			Get_Cached_Date "$File" "$Ts" +%Y/%m/%d '0000/00/00'
			;;
		esac
		;;
	created)
		Ts=$(Get_File_Timestamps "$File")
		printf '%s' "${Ts%%|*}" | sed 's/\..*//; s/ /_/'
		;;
	modified)
		Ts=$(Get_File_Timestamps "$File")
		printf '%s' "${Ts#*|}" | sed 's/\..*//; s/ /_/'
		;;
	accessed)
		stat -c %x -- "$File" 2>/dev/null | sed 's/\..*//; s/ /_/'
		;;

	# File identity
	extension)
		local CExt
		CExt=$(Get_Compound_Ext "$File") || CExt=$(Get_File_Ext "$File")
		printf '%s' "$CExt"
		;;
	compressed)
		local CName
		CName=$(Archive_Main_Name "$File") || CName=$(Get_File_Name "$File")
		printf '%s' "$CName"
		;;
	mime-ext)
		local MExt Rc
		MExt=$(Get_MIME_Best_Extension "$File")
		Rc=$?
		if [ "$Rc" -eq 0 ] && [ -n "$MExt" ]; then
			printf '%s' "$MExt"
		else
			return 1
		fi
		;;
	mime)
		printf '%s' "$Mime"
		;;
	mime-main)
		printf '%s' "${Main^^}"
		;;
	mime-sub)
		printf '%s' "${Mime#*/}"
		;;

	# Checksums
	md5 | md5sum)
		Get_MD5Sum "$File"
		;;
	sha1 | sha1sum)
		Get_SHA1Sum "$File"
		;;
	sha224 | sha224sum)
		Get_SHA224Sum "$File"
		;;
	sha256 | sha256sum)
		Get_SHA256Sum "$File"
		;;
	sha384 | sha384sum)
		Get_SHA384Sum "$File"
		;;
	sha512 | sha512sum)
		Get_SHA512Sum "$File"
		;;
	sha | shasum)
		Get_SHA256Sum "$File"
		;;
	b2 | blake2)
		Get_B2Sum "$File"
		;;
	crc32 | cksum)
		Get_CRC32 "$File"
		;;

	# Random
	random)
		printf '%s' "$RANDOM"
		;;
	random[0-9]*)
		N=${Key#random}
		Out=''
		while [ "$N" -gt 0 ] 2>/dev/null; do
			Out="$Out$RANDOM"
			N=$((N - 1))
		done
		printf '%s' "$Out"
		;;

	# Size and media dimensions
	size)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] && printf '%s' "$WxH" || return 1
		else
			Get_File_Size_Human "$File"
		fi
		;;
	format)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] || return 1
			printf '%s/%s' "$(Media_Tier "$WxH")" "$(Media_Orient "$WxH")"
		else
			Size_Unit_Name "$File"
		fi
		;;
	size+format)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] || return 1
			printf '%s/%s/%s' "$WxH" "$(Media_Tier "$WxH")" "$(Media_Orient "$WxH")"
		else
			printf '%s/%s' "$(Get_File_Size_Human "$File")" "$(Size_Unit_Name "$File")"
		fi
		;;
	format+size)
		if [ "$Main" = 'image' ] || [ "$Main" = 'video' ]; then
			if [ "$Main" = 'image' ]; then WxH=$(Get_Image_WxH "$File"); else WxH=$(Get_Media_WxH "$File"); fi
			[ -n "$WxH" ] || return 1
			printf '%s/%s/%s' "$(Media_Tier "$WxH")" "$(Media_Orient "$WxH")" "$WxH"
		else
			printf '%s/%s' "$(Size_Unit_Name "$File")" "$(Get_File_Size_Human "$File")"
		fi
		;;
	duration)
		Video_Duration_Tag "$File"
		;;

	# Metadata
	camera)
		Exif_Camera_Dir "$File"
		;;
	exifdate)
		Exif_Date_Dir "$File"
		;;
	title)
		Title_Name "$File" "$Main"
		;;

	# Name helpers (for --rename)
	long | base)
		Get_File_Base "$File"
		;;
	short | name)
		Get_Base_Name "$File"
		;;
	folder)
		local Folder
		Folder=$(Get_File_Dir "$File")
		Folder=${Folder##*/}
		[ "$Folder" = '.' ] && Folder=''
		[ -n "$Folder" ] && printf '%s' "$Folder" || return 1
		;;
	folder_name | foldername)
		local Folder
		Folder=$(Get_File_Dir "$File")
		Folder=${Folder##*/}
		[ "$Folder" = '.' ] && Folder=''
		if [ -n "$Folder" ]; then
			printf '%s_%s' "$Folder" "$(Get_Base_Name "$File")"
		else
			Get_Base_Name "$File"
		fi
		;;

	*)
		return 2
		;;
	esac
}
