Title_Name() {
	local File=$1 Main=$2 T A Al

	case "$Main" in
	application)
		Get_Doc_Title "$File"
		;;
	image)
		if ! T=$(Exif_Date_Dir "$File"); then
			T=$(stat -c %y -- "$File" 2>/dev/null)
			T=$(date -d "${T%%.*}" +%Y-%m-%d 2>/dev/null)
		fi
		[ -n "$T" ] && printf '%s' "$T" || Get_File_Name "$File"
		;;
	audio)
		A=$(Get_Audio_Artist "$File" 2>/dev/null)
		Al=$(Get_Audio_Album "$File" 2>/dev/null)
		T=$(Get_Audio_Title "$File" 2>/dev/null)
		T=$(printf '%s_%s_%s' "${A:-}" "${Al:-}" "${T:-}" | sed 's/_\+/_/g; s/^_//; s/_$//')
		[ -n "$T" ] && printf '%s' "$T" || Get_File_Name "$File"
		;;
	video)
		A=$(Get_Media_Artist "$File" 2>/dev/null)
		T=$(Get_Media_Title "$File" 2>/dev/null)
		T=$(printf '%s_%s' "${A:-}" "${T:-}" | sed 's/_\+/_/g; s/^_//; s/_$//')
		[ -n "$T" ] && printf '%s' "$T" || Get_File_Name "$File"
		;;
	*)
		Get_File_Name "$File"
		;;
	esac
}
