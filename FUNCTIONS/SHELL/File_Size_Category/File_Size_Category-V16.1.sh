File_Size_Category() {
	local Size

	Size=$(Get_File_Size "$1") || return 1

	if [ "$Size" -lt 1024 ]; then
		printf 'Byte'
	elif [ "$Size" -lt 1048576 ]; then
		printf 'KiloByte'
	elif [ "$Size" -lt 1073741824 ]; then
		printf 'MegaByte'
	elif [ "$Size" -lt 1099511627776 ]; then
		printf 'GigaByte'
	else
		printf 'TeraByte'
	fi
}
