Print_Line() {
	local Char=${1:--}
	local Width=${2:-80}
	local Line

	# Build the line without external tools.
	Line=$(printf '%*s' "$Width" '' | tr ' ' "$Char")
	printf '%s\n' "$Line"
}
