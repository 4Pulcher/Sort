Get_Date_Part() {
	local File=$1
	local Format=$2
	local Fallback=${3:-}
	local Time

	Time=$(Get_File_Birth "$File")

	if [[ "$Time" != "0" ]]; then
		date -d "@$Time" "$Format" 2>/dev/null || printf '%s' "$Fallback"
	else
		printf '%s' "$Fallback"
	fi
}
