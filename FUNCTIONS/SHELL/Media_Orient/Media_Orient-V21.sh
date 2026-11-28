Media_Orient() {
	local WxH=$1 W=${1%x*} H=${1#*x}

	if [ "$W" = "$H" ]; then
		printf 'SQUARE'
	elif [ "$W" -gt "$H" ] 2>/dev/null; then
		printf 'WIDE'
	else
		printf 'HIGH'
	fi
}
