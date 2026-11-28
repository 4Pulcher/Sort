Get_WxH_Format() {
	[[ ! "$1" =~ ^[0-9]+x[0-9]+$ ]] && {
		printf "ZERO/ZERO"
		return
	}

	local W=${1%%x*}
	local H=${1##*x}
	local MAX=$W
	local SIZE="HUGE"
	local ASPECT="SQUARE"

	((H > W)) && MAX=$H

	if ((W == 0 || H == 0)); then
		SIZE="ZERO"
	elif ((MAX < 512)); then
		SIZE="SMALLER"
	elif ((MAX < 1024)); then
		SIZE="SMALL"
	elif ((MAX < 2048)); then
		SIZE="MEDIUM"
	elif ((MAX < 4096)); then
		SIZE="BIG"
	elif ((MAX < 8096)); then
		SIZE="BIGGER"
	fi

	((W > H)) && ASPECT="WIDE"
	((H > W)) && ASPECT="HIGH"

	printf "%s/%s" "$SIZE" "$ASPECT"
}
