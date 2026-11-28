Media_Tier() {
	local WxH=$1 W=${1%x*} H=${1#*x} Big

	if [ "$W" -ge "$H" ] 2>/dev/null; then Big=$W; else Big=$H; fi

	if [ "$Big" -lt 64 ]; then
		printf 'TINY'
	elif [ "$Big" -lt 128 ]; then
		printf 'MINI'
	elif [ "$Big" -lt 320 ]; then
		printf 'SMALLER'
	elif [ "$Big" -lt 640 ]; then
		printf 'SMALL'
	elif [ "$Big" -lt 1280 ]; then
		printf 'MEDIUM'
	elif [ "$Big" -lt 1920 ]; then
		printf 'BIG'
	elif [ "$Big" -lt 3840 ]; then
		printf 'BIGGER'
	else
		printf 'HUGE'
	fi
}
