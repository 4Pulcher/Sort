Resolve_Path_Segment() {
	local Req="${1,,}"
	local File="$2"
	local Res=""

	if [[ "$1" == *"'"* ]]; then
		Resolve_Joined_Tokens "$1" "$File"
		return
	fi

	case "$Req" in
	year) Res=$(Get_Date_Part "$File" '+%Y' '0000') ;;
	month) Res=$(Get_Date_Part "$File" '+%m' '00') ;;
	day) Res=$(Get_Date_Part "$File" '+%d' '00') ;;
	extension)
		Res=${File##*.}
		Res=${Res^^}
		;;
	mime) Res=${MIME^^} ;;
	mime-main) Res=${MIMEMain^^} ;;
	mime-sub) Res=${MIMESub^^} ;;

	size | format)
		if [[ "$MIMEMain" =~ ^(image|video)$ ]]; then
			local WxH Fmt
			WxH=$(Get_WxH "$File")
			Fmt=$(Get_WxH_Format "$WxH")

			if [[ "$WxH" == "0x0" || "$Fmt" == "ZERO/ZERO" ]]; then
				Res="ZERO"
			elif [[ "$Req" == size ]]; then
				Res="$WxH"
			else
				Res="$Fmt"
			fi
		else
			local S Label
			S=$(Get_File_Size "$File")
			Label=$(Get_Size_Label "$S" format)

			if [[ "$Req" == size ]]; then
				Res=$(Get_Size_Label "$S" dec)
			else
				Res=${Label//[0-9]/}
			fi
		fi
		;;

	created) Res=$(Get_File_Creation_Time "$File") ;;
	modified) Res=$(Get_File_Modification_Time "$File") ;;
	accessed) Res=$(Get_File_Access_Time "$File") ;;

	md5) Res=$(Get_MD5Sum "$File") ;;
	md5sum | shasum | sha1deep | sha1sum | sha224sum | sha256deep | sha256sum | sha384sum | sha512sum)
		Res=$(/usr/bin/$Req -b "$File" | cut -d' ' -f1)
		;;

	random) Res="${RANDOM}${RANDOM}" ;;
	*) Res="$1" ;;
	esac

	printf "%s" "$Res"
}
