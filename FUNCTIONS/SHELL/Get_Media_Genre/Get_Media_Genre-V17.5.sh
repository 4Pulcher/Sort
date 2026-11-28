Get_Media_Genre() {
	local File=$1

	_Probe format_tags=genre "$File"
}
