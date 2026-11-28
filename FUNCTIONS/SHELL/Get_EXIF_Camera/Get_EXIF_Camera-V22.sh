Get_EXIF_Camera() {
	local File=$1
	local Make Model

	_Exif_Has_Reader || return 127
	Make=$(_Exif_Read Make "$File") || Make=''
	Model=$(_Exif_Read Model "$File") || Model=''

	[ -n "$Make" ] || [ -n "$Model" ] || return 1
	printf '%s %s' "$Make" "$Model"
}
