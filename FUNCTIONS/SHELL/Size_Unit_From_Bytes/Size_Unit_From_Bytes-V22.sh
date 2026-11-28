Size_Unit_From_Bytes() {
	local Size=$1

	if [ "$Size" -lt 1024 ]; then
		printf 'Byte'
	elif [ "$Size" -lt 1048576 ]; then
		printf 'Kilo'
	elif [ "$Size" -lt 1073741824 ]; then
		printf 'Mega'
	elif [ "$Size" -lt 1099511627776 ]; then
		printf 'Giga'
	else
		printf 'Tera'
	fi
}
