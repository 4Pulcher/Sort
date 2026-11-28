Get_Media_Title() {
	local File=$1

	_Probe format_tags=title "$File"
}
