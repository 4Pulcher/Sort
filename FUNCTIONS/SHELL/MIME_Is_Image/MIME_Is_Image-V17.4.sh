MIME_Is_Image() {
	local File=$1

	[[ "$(Get_MIME_Main "$File")" == "image" ]]
}
