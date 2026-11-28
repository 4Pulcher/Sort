Get_Base_Name() {
	local Base=${1##*/}
	local Suffix

	if Suffix=$(Get_Compound_Ext "$1"); then
		printf '%s' "${Base%."$Suffix"}"
	else
		Get_File_Name "$1"
	fi
}
