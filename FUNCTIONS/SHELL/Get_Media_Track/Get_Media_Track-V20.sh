Get_Media_Track() {
	local File=$1

	_Probe format_tags=track "$File"
}
