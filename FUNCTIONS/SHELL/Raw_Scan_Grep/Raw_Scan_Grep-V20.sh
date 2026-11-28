Raw_Scan_Grep() {
	local Base=$1 Pos Sig Off Hit
	while IFS='|' read -r Sig Cmd; do
		[ -n "${RawName[$Sig]}" ] || continue
		while IFS=: read -r Pos _; do
			[ -n "$Pos" ] || continue
			[ $(( Pos % 2 )) -eq 0 ] || continue
			Off=${RawOff[$Sig]}
			Hit=$(( Base + Pos / 2 - Off ))
			[ $Hit -ge 0 ] && printf '%s\n' "$Hit|$Sig"
		done < <(eval "$Cmd" <"$Tmp_Raw_Hex" 2>/dev/null)
	done <<-PATTERNS
$(printf '%s' "$Raw_Patterns")
PATTERNS
}
