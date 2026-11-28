Build_Extension() {
	local File=$1 Mime=$2

	case "$Append" in
	none)
		printf ''
		;;
	mime)
		printf '.%s' "${Mime//\//.}"
		;;
	mime-sub)
		printf '.%s' "${Mime#*/}"
		;;
	*)
		printf '.%s' "$(Get_File_Ext "$File")"
		;;
	esac
}
