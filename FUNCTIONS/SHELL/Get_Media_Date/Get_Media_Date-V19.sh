Get_Media_Date() {
	local File=$1

	_Probe format_tags=date "$File"
}
