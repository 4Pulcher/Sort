Magic_Match() {
	local H=$1 Pos=$(( $2 * 2 )) P=$3 I C
	[ "${#H}" -lt $(( Pos + ${#P} )) ] && return 1
	for (( I=0; I<${#P}; I++ )); do
		C=${P:I:1}
		if [ "$C" != '?' ] && [ "${H:Pos+I:1}" != "$C" ]; then
			return 1
		fi
	done
	return 0
}
