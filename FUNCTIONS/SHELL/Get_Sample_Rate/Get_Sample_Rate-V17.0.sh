Get_Sample_Rate() {
	local File=$1

	_Probe_Stream stream=sample_rate a:0 "$File"
}
