Get_Duration() {
	local File=$1

	_Probe format=duration "$File"
}
