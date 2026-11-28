Get_Image_Camera() {
	local File=$1
	local Make Model

	Make=$(_IM_Identify '%[exif:Make]' "$File") || Make=''
	Model=$(_IM_Identify '%[exif:Model]' "$File") || Model=''

	[ -n "$Make" ] || [ -n "$Model" ] || return 1
	printf '%s %s' "$Make" "$Model"
}
