Get_EXIF_Lens() {
	local File=$1
	local Lens

	_Exif_Has_Reader || return 127
	Lens=$(_Exif_Read LensModel "$File") || Lens=$(_Exif_Read LensMake "$File") || return 1
	printf '%s' "$Lens"
}
