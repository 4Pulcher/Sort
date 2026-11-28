Get_File_Ext() {
	local BaseName=${1##*/}

	# Edge-case guard: files with no dot ("Makefile") or single-dot hidden
	# dotfiles (".bashrc") have no extension and return an empty string.
	if [[ "$BaseName" != *.* || ("$BaseName" == .* && "$BaseName" != *.*.*) ]]; then
		printf ''
	else
		printf '%s' "${BaseName##*.}"
	fi
}
