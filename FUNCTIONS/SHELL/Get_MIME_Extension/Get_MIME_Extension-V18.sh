Get_MIME_Extension() {
	local File=$1
	local MIME

	MIME=$(Get_MIME_Type "$File") || return $?
	_MIME_Lookup_Ext "$MIME"
}
