MIME_Is_Video() {
	local File=$1

	[[ "$(Get_MIME_Main "$File")" == "video" ]]
}
