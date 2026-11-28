Magic_Report() {
	local F=$1 H Detected Name Exts Ext Verdict
	H=$(Magic_Nibbles "$F" 16)
	[ -n "$H" ] || H='(empty)'
	Detected=$(Magic_Detect "$H") && Name=${Detected%%|*} Exts=${Detected#*|} || Name='?' Exts=''
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
		"$F" "$H" "${Name:-UNKNOWN}" "$Ext" "$Verdict"
}
