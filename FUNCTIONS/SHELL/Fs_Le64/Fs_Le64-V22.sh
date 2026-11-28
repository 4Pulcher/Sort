Fs_Le64() {
	local H=$1 P=$2 V=0 K B
	for K in 0 1 2 3 4 5 6 7; do
		B=$(( 16#${H:$(( P + K * 2 )):2} ))
		V=$(( V + B * ( 256 ** K ) ))
	done
	printf '%s' "$V"
}
