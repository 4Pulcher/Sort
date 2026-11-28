Get_Compound_Ext() {
	local Base=${1##*/}
	local Low=${Base,,}
	local Comp

	local Suffix

	for Comp in .tar.gz .tgz .tar.bz2 .tbz2 .tbz .tar.xz .txz .tar.zst .tzst .tar.lzma .tar.lz; do
		if [[ "$Low" == *"$Comp" ]]; then
			Suffix=${Base: -${#Comp}}
			printf '%s' "${Suffix#.}"
			return 0
		fi
	done

	return 1
}
