Get_Doc_Title() {
	local T
	T=$(grep -a '/Title' "$1" | head -n1 | sed 's/.*(\(.*\)).*/\1/')
	[[ -z "$T" ]] && Get_File_Name "$1" || Sanitize "$T"
}
