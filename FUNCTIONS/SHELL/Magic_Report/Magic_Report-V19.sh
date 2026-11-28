Magic_Report() {
	local F=$1 H Detected Key Rest Name Exts Ext Verdict
	H=$(Magic_Nibbles "$F" 32774)
	[ -n "$H" ] || H='(empty)'
	if Detected=$(Magic_Detect "$H"); then
		Key=${Detected%%|*}
		Rest=${Detected#*|}
		Name=${Rest%%|*}
		Exts=${Rest#*|}
	else
		Key='' Name='?' Exts=''
	fi
	Ext=${F##*.}
	if [ "$Ext" = "${F##*/}" ]; then Ext='(none)'; else Ext=${Ext,,}; fi
	if [ "$Name" = '?' ]; then
		Verdict='UNKNOWN'
	elif [ "$Ext" = '(none)' ]; then
		Verdict='NO-EXT'
	elif case ",$Exts," in *",$Ext,"*) true ;; *) false ;; esac; then
		Verdict='MATCH'
	else
		Verdict='MISMATCH'
	fi
	printf '%s\n\tmagic: %s\n\tdetected: %s\n\textension: %s\n\tverdict: %s\n' \
		"$F" "${H:0:32}" "${Name:-UNKNOWN}" "$Ext" "$Verdict"
}
