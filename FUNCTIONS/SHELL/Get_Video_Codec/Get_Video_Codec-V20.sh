Get_Video_Codec() {
	local File=$1

	_Probe_Stream stream=codec_name v:0 "$File"
}
