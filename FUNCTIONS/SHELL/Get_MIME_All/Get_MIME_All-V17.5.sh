Get_MIME_All() {
	local File=$1
	local Type Desc Charset Ext Magic

	Type=$(Get_MIME_Type "$File") || return $?
	Desc=$(Get_MIME_Description "$File" 2>/dev/null || true)
	Charset=$(Get_MIME_Charset "$File" 2>/dev/null || true)
	Ext=$(Get_MIME_Extension "$File" 2>/dev/null || true)
	Magic=$(Get_Magic_Bytes "$File" 8 2>/dev/null || true)

	printf 'Type:        %s\n' "$Type"
	printf 'Main:        %s\n' "${Type%%/*}"
	printf 'Sub:         %s\n' "${Type#*/}"
	printf 'Description: %s\n' "$Desc"
	printf 'Charset:     %s\n' "$Charset"
	printf 'Extension:   %s\n' "$Ext"
	printf 'Magic:       %s\n' "$Magic"
}
