Image_Form() {
	local WxH=$1 W H

	W=${WxH%x*}
	H=${WxH#*x}

	if [ "$W" = "$H" ]; then
		printf 'Square'
	elif [ "$H" -gt "$W" ] 2>/dev/null; then
		printf 'Portrait'
	else
		printf 'Landscape'
	fi
}
