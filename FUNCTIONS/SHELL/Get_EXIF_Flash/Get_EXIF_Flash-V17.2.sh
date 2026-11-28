Get_EXIF_Flash() {
	local File=$1
	local Flash

	Flash=$(_Exif_Read Flash "$File") || return $?
	printf '%s' "$Flash"
}
