Raw_Carve_Size() {
	local H=$1 Name=$2 Cap=$3 End Clen Type Pos B0 B1
	local Size=${#H}; Size=$(( Size / 2 ))
	[ $Size -gt $Cap ] && Size=$Cap
	local Exact=capped
	case $Name in
	'PNG image')
		Pos=8
		while [ $(( Pos * 2 + 24 )) -le ${#H} ]; do
			Clen=$(( 16#${H:Pos*2:8} ))
			Type=${H:Pos*2+8:8}
			Pos=$(( Pos + 12 + Clen ))
			if [ "$Type" = '49454e44' ]; then Size=$Pos; Exact=exact; break; fi
			[ $Clen -gt $Size ] && { Size=$Pos; break; }
		done
		;;
	'JPEG image')
		End=$(printf '%s' "$H" | grep -obF -- 'ffd9' | tail -1 | cut -d: -f1)
		if [ -n "$End" ]; then Size=$(( End / 2 + 2 )); Exact=exact; fi
		;;
	'GIF image')
		End=$(printf '%s' "$H" | grep -obF -- '3b' | awk -F: -v m=26 '$1 >= m' | tail -1 | cut -d: -f1)
		if [ -n "$End" ]; then Size=$(( End / 2 + 1 )); Exact=exact; fi
		;;
	'ZIP/'* | 'ZIP archive'*)
		End=$(printf '%s' "$H" | grep -obF -- '504b0506' | tail -1 | cut -d: -f1)
		if [ -n "$End" ]; then
			B0=$(( End / 2 + 20 )); B1=$(( End / 2 + 21 ))
			if [ $(( B1 + 1 )) -le $(( ${#H} / 2 )) ]; then
				Size=$(( End / 2 + 22 + 16#${H:B0*2:2} + 16#${H:B1*2:2} * 256 ))
				Exact=exact
			fi
		fi
		;;
	'PDF document')
		End=$(printf '%s' "$H" | grep -obF -- '2525454f46' | tail -1 | cut -d: -f1)
		if [ -n "$End" ]; then Size=$(( End / 2 + 5 )); Exact=exact; fi
		;;
	esac
	[ $Size -gt $Cap ] && Size=$Cap
	printf '%s %s' "$Size" "$Exact"
}
