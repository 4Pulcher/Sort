Get_Doc_Title() {
	local Title
	Title=$(
		grep -a '/Title' "$1" 2>/dev/null | head -n 1 |
			sed 's/.*(\(.*\)).*/\1/' | tr -d '/\\:*?"<>|' | tr ' ' '_'
	)
	[[ -z "$Title" ]] && Title=$(Get_File_Name "$1")
	printf '%s' "${Title:-ERROR}"
}
