Video_Duration_Tag() {
	local Seconds H M S

	Seconds=$(Get_Duration "$1") || return 1
	Seconds=${Seconds%.*}
	Seconds=${Seconds:-0}

	H=$((Seconds / 3600))
	M=$(((Seconds % 3600) / 60))
	S=$((Seconds % 60))

	printf '%02d-%02d-%02d' "$H" "$M" "$S"
}
