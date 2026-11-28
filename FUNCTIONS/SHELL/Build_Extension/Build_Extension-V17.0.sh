Build_Extension() {
	local File=$1 Mime=$2 Ext Rc

	case "$Append" in
	'')
		Ext=$(Get_Compound_Ext "$File") || Ext=$(Get_File_Ext "$File")
		[ -n "$Ext" ] && printf '.%s' "$Ext"
		;;
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
		Ext=$(Resolve_Segment "$Append" "$File" "$Mime" "${Mime%%/*}")
		Rc=$?
		if [ "$Rc" -eq 2 ]; then
			printf '.%s' "$Append"
		elif [ "$Rc" -eq 0 ] && [ -n "$Ext" ]; then
			printf '.%s' "$Ext"
		else
			Ext=$(Get_Compound_Ext "$File") || Ext=$(Get_File_Ext "$File")
			[ -n "$Ext" ] && printf '.%s' "$Ext"
		fi
		;;
	esac
}
