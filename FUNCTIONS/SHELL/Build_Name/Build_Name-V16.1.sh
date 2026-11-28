Build_Name() {
	local File=$1 Folder

	case "$Rename" in
	sha256sum)
		Get_Hash sha256 "$File" || return 1
		;;
	random)
		printf 'RND-%s-%s' "$RANDOM" "$SECONDS"
		;;
	title)
		# Internal document title, falling back to the filename inside Get_Doc_Title
		Sanitize_Name "$(Get_Doc_Title "$File")"
		;;
	long)
		Get_File_Base "$File"
		;;
	short)
		Get_File_Name "$File"
		;;
	*)
		# Default: <folder>_<name>, flat and filename-safe;
		# a file in the current directory has no folder part
		Folder=$(Get_File_Dir "$File")
		Folder=${Folder##*/}
		[ "$Folder" = '.' ] && Folder=''

		if [ -n "$Folder" ]; then
			printf '%s_%s' "$Folder" "$(Get_File_Name "$File")"
		else
			Get_File_Name "$File"
		fi
		;;
	esac
}
