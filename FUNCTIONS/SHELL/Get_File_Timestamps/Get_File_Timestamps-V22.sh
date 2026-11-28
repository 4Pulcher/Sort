Get_File_Timestamps() {
	local Ts

	Ts=${Sort_Stat_Cache[$1]-}
	if [ -z "$Ts" ]; then
		Ts=$(stat -c '%w|%y' -- "$1" 2>/dev/null)
		Sort_Stat_Cache[$1]=$Ts
	fi
	printf '%s' "$Ts"
}
