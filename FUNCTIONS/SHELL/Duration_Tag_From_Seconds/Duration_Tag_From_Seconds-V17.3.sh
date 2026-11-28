Duration_Tag_From_Seconds() {
	local Seconds=${1%.*}
	Seconds=${Seconds:-0}
	local H=$((Seconds / 3600))
	local M=$(((Seconds % 3600) / 60))
	local S=$((Seconds % 60))

	printf '%02d-%02d-%02d' "$H" "$M" "$S"
}
