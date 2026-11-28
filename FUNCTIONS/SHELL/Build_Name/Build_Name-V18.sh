Build_Name() {
	local File=$1 Mime=$2 Main=$3 Name Rc

	if [ "$Title_Mode" -eq 1 ] && [ -z "$Rename" ]; then
		Sanitize_Name "$(Title_Name "$File" "$Main")"
		return 0
	fi

	case "$Rename" in
	'')
		Name=$(Resolve_Segment folder_name "$File" "$Mime" "$Main")
		[ -n "$Name" ] && printf '%s' "$Name" || Get_Base_Name "$File"
		;;
	*)
		Name=$(Resolve_Segment "$Rename" "$File" "$Mime" "$Main")
		Rc=$?
		if [ "$Rc" -eq 2 ]; then
			printf '%s' "$Rename"
		elif [ "$Rc" -eq 0 ] && [ -n "$Name" ]; then
			Sanitize_Name "$Name"
		else
			return 1
		fi
		;;
	esac
}
