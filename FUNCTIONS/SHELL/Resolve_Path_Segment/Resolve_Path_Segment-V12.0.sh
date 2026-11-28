Resolve_Path_Segment() {
	local Req=${1,,}
	local File=$2

	case "$Req" in
	year) Get_Date_Part "$File" '+%Y' '0000' ;;
	month) Get_Date_Part "$File" '+%m' '00' ;;
	day) Get_Date_Part "$File" '+%d' '00' ;;
	year+month) Get_Date_Part "$File" '+%Y/%m' '0000/00' ;;
	year+month+day) Get_Date_Part "$File" '+%Y/%m/%d' '0000/00/00' ;;
	created) Get_File_Creation_Time "$File" ;;
	modified) Get_File_Modification_Time "$File" ;;
	accessed) Get_File_Access_Time "$File" ;;

	extension) Get_File_Ext "$File" ;;
	mime) printf '%s' "${MIME^^}" ;;
	mime-main) printf '%s' "${MIMEMain^^}" ;;
	mime-sub) printf '%s' "${MIMESub^^}" ;;

	size | format | size+format | format+size)
		if [[ "$MIMEMain" == "image" || "$MIMEMain" == "video" ]]; then
			local Dimensions MediaFormat
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
			local Bytes Value UnitIndex Divisor
			local -a Units

			Bytes=$(Get_File_Size "$File")
			Value=$Bytes
			UnitIndex=0
			Divisor=1000
			Units=("B" "KB" "MB" "GB" "TB" "PB")

			if [[ "$Req" == "size+format" ]]; then
				Divisor=1024
				Units=("B" "KiB" "MiB" "GiB" "TiB")
			elif [[ "$Req" == format* ]]; then
				Divisor=1000
				Units=("Byte" "Kilo" "Mega" "Giga" "Tera")
			fi

			while ((Value >= Divisor && UnitIndex < ${#Units[@]} - 1)); do
				((UnitIndex += 1))
				Value=$((Value / Divisor))
			done

			case "$Req" in
			size) printf '%s%s' "$Value" "${Units[$UnitIndex]}" ;;
			size+format) printf '%s_%s' "$Value" "${Units[$UnitIndex]}" ;;
			format) printf '%s' "${Units[$UnitIndex]}" ;;
			format+size) printf '%s/%s' "${Units[$UnitIndex]}" "$Value" ;;
			esac
		fi
		;;

	md5 | md5sum) Get_MD5Sum "$File" ;;
	sha) Get_SHA_Keys shasum "$File" ;;
	sha1 | sha224 | sha256 | sha384 | sha512) Get_SHA_Keys "${Req}sum" "$File" ;;
	shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum) Get_SHA_Keys "$Req" "$File" ;;

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
	*)
		printf 'ERROR'
		return 1
		;;
	esac
}
