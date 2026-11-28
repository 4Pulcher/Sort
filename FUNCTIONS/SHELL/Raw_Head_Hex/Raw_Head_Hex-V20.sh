Raw_Head_Hex() {
	dd if="$1" bs=64k iflag=skip_bytes,count_bytes \
		skip="$2" count="$3" 2>/dev/null |
		od -An -v -tx1 | tr -d ' \n'
}
