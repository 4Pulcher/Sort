Draw_Line() {
	local Width Symbol
	Width=$(tput cols 2>/dev/null)
	Width=${Width:-80}
	Symbol=${1:-=}
	local LineStr
	printf -v LineStr '\n%*s\n\n' "$Width" ''
	Log_Print '%s' "${LineStr// /$Symbol}"
}
