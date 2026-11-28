Get_File_Ext() {
	local BaseName=${1##*/}

	# A name without a dot (or a hidden name such as ".profile") has no
	# extension. Otherwise, return the text following the final dot.
	if [[ "$BaseName" != *.* || "$BaseName" == .* && "$BaseName" != *.*.* ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}
