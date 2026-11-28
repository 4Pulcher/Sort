Resolve_Path_Segment() {
	local Req=${1,,}
	local File=$2

	case "$Req" in
	# Birth-time date components.
	year)
		Get_Date_Part "$File" '+%Y' '0000'
		;;
	month)
		Get_Date_Part "$File" '+%m' '00'
		;;
	day)
		Get_Date_Part "$File" '+%d' '00'
		;;
	year+month)
		Get_Date_Part "$File" '+%Y/%m' '0000/00'
		;;
	year+month+day)
		Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00'
		;;

	# Original extension and MIME components.
	extension)
		Get_File_Ext "$File"
		;;
	mime)
		printf '%s' "${MIME^^}"
		;;
	mime-main)
		printf '%s' "${MIMEMain^^}"
		;;
	mime-sub)
		printf '%s' "${MIMESub^^}"
		;;

	# Size and format values behave differently for media and other files.
	size | format | size+format | format+size)
		if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
			local Dimensions MediaFormat

			# Images are inspected by identify; videos by ffprobe.
			if [[ "$MIMEMain" == "image" ]]; then
				Dimensions=$(Get_Image_WxH "$File")
			else
				Dimensions=$(Get_Media_WxH "$File")
			fi

			MediaFormat=$(Get_WxH_Format "$Dimensions")

			if [[ "$MediaFormat" == "ZERO" ]]; then
				printf 'ZERO'
			elif [[ "$Req" == "size" ]]; then
				printf '%s' "$Dimensions"
			elif [[ "$Req" == "format" ]]; then
				printf '%s' "$MediaFormat"
			else
				printf '%s/%s' "$MediaFormat" "$Dimensions"
			fi
		else
			# For non-media files, convert the byte count to a unit label.
			local Bytes Value UnitIndex Divisor
			local -a Units

			Bytes=$(Get_File_Size "$File")
			Value=$Bytes
			UnitIndex=0
			Divisor=1000
			Units=("B" "KB" "MB" "GB" "TB" "PB")

			# size+format uses binary units; format values use decimal units.
			if [[ "$Req" == "size+format" ]]; then
				Divisor=1024
				Units=("B" "KiB" "MiB" "GiB" "TiB")
			elif [[ "$Req" == format* ]]; then
				Divisor=1000
				Units=("Byte" "Kilo" "Mega" "Giga" "Tera")
			fi

			# Divide until the value fits the selected unit or units run out.
			while ((Value >= Divisor && UnitIndex < ${#Units[@]} - 1)); do
				((UnitIndex += 1))
				Value=$((Value / Divisor))
			done

			case "$Req" in
			size)
				printf '%s%s' "$Value" "${Units[$UnitIndex]}"
				;;
			size+format)
				printf '%s_%s' "$Value" "${Units[$UnitIndex]}"
				;;
			format)
				printf '%s' "${Units[$UnitIndex]}"
				;;
			format+size)
				printf '%s/%s' "${Units[$UnitIndex]}" "$Value"
				;;
			esac
		fi
		;;

	# Filesystem timestamps.
	created)
		Get_File_Creation_Time "$File"
		;;
	modified)
		Get_File_Modification_Time "$File"
		;;
	accessed)
		Get_File_Access_Time "$File"
		;;

	# Checksums. Some algorithms require optional external programs.
	md5 | md5sum)
		Get_MD5Sum "$File"
		;;
	sha)
		Get_SHA_Keys shasum "$File"
		;;
	sha1 | sha224 | sha256 | sha384 | sha512)
		Get_SHA_Keys "${Req}sum" "$File"
		;;
	shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum)
		Get_SHA_Keys "$Req" "$File"
		;;

	# random returns one Bash random value; randomN concatenates N values.
	random*)
		local Count=${Req#random}

		if [[ -z "$Count" ]]; then
			printf '%s' "$RANDOM"
		elif [[ "$Count" =~ ^[0-9]+$ ]]; then
			while ((Count > 0)); do
				printf '%s' "$RANDOM"
				((Count -= 1))
			done
		else
			printf 'ERROR'
			return 1
		fi
		;;

	# Unknown keywords produce an explicit error marker.
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}
