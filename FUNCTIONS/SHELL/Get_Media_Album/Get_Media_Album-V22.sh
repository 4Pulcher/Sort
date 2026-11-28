Get_Media_Album() {
	local File=$1

	_Probe format_tags=album "$File"
}
