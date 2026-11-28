Exif_Date_Dir() {
	local Date Dir

	Date=$(Get_EXIF_Date "$1" 2>/dev/null) || return 1
	Dir=${Date%% *}
	Dir=${Dir//:/-}

	[[ "$Dir" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
	printf '%s' "$Dir"
}
