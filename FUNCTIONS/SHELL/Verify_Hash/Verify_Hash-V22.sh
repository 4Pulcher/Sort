Verify_Hash() {
	local File=$1
	local Expected=$2
	local Actual

	Actual=$(Get_Hash sha256 "$File") || return 1
	[[ "$Actual" == "${Expected,,}" ]]
}
