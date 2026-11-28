Get_File_Ext() {
	local BaseName=${1##*/}
	if [[ "$BaseName" != *.* || ("$BaseName" == .* && "$BaseName" != *.*.*) ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}
