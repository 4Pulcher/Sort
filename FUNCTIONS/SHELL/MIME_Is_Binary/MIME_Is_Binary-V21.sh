MIME_Is_Binary() {
	local File=$1
	local Charset

	Charset=$(Get_MIME_Charset "$File") || return $?
	[[ "$Charset" == "binary" ]]
}
