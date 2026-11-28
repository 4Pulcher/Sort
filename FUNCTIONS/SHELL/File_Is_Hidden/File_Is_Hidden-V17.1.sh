File_Is_Hidden() {
	local Base=${1##*/}
	[[ "$Base" == .* ]]
}
