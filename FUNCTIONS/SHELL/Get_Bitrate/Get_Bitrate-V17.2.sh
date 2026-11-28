Get_Bitrate() {
	local File=$1

	_Probe format=bit_rate "$File"
}
