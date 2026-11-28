MIME_Is_Audio() {
	local File=$1

	[[ "$(Get_MIME_Main "$File")" == "audio" ]]
}
