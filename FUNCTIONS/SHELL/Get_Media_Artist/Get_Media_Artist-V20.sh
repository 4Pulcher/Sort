Get_Media_Artist() {
	local File=$1

	_Probe format_tags=artist "$File"
}
