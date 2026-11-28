Get_FPS() {
	local File=$1
	local Fraction Num Den

	Fraction=$(_Probe_Stream stream=avg_frame_rate v:0 "$File") || return $?

	# avg_frame_rate is a fraction like "30000/1001" - evaluate it safely.
	Num=${Fraction%%/*}
	Den=${Fraction##*/}
	if [[ "$Num" =~ ^[0-9]+$ ]] && [[ "$Den" =~ ^[0-9]+$ ]] && ((Den > 0)); then
		printf '%d.%d' $((Num / Den)) $(((Num % Den) * 10 / Den))
	else
		printf '%s' "$Fraction"
	fi
}
