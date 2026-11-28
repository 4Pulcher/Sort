Get_Date_Part() {
	local File=$1 Format=$2 Fallback=$3 Time
	Time=$(Get_File_Birth "$File")
	if [[ "$Time" != "0" ]]; then
		date -d "@$Time" "$Format" 2>/dev/null
	else
		printf '%s' "$Fallback"
	fi
}
