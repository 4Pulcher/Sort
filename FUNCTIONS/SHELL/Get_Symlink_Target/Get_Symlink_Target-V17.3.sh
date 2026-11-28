Get_Symlink_Target() {
	local File=$1

	[ -L "$File" ] || return 1
	readlink -- "$File"
}
