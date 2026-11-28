Get_Audio_Codec() {
	local File=$1

	_Probe_Stream stream=codec_name a:0 "$File"
}
