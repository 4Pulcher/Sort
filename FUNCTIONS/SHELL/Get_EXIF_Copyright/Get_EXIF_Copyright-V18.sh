Get_EXIF_Copyright() {
	local File=$1
	local Copyright

	Copyright=$(_Exif_Read Copyright "$File") || return $?
	printf '%s' "$Copyright"
}
