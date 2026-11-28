Get_Duration_Human() {
	local File=$1
	local Seconds
	local H M S

	Seconds=$(_Probe format=duration "$File") || return $?
	# Keep only the integer part before converting.
	Seconds=${Seconds%%.*}

	H=$((Seconds / 3600))
	M=$(((Seconds % 3600) / 60))
	S=$((Seconds % 60))

	printf '%02d:%02d:%02d' "$H" "$M" "$S"
}
