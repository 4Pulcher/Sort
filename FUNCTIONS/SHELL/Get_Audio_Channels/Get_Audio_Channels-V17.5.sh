Get_Audio_Channels() {
	local File=$1

	_Probe_Stream stream=channels a:0 "$File"
}
