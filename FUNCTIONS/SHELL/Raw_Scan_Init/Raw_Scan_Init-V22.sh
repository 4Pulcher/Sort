Raw_Scan_Init() {
	local Key Fields Name Exts Sig Off Pat
	[ -n "$Raw_Patterns" ] && return 0
	for Key in "${!Magic[@]}"; do
		IFS='|' read -r Name Exts Sig Off <<< "${Magic[$Key]}"
		[ "${#Sig}" -ge 4 ] || continue
		[ -n "${RawName[$Sig]}" ] && continue
		RawName[$Sig]=$Name
		RawExts[$Sig]=$Exts
		RawOff[$Sig]=${Off:-0}
		Pat=${Sig//\?/[0-9a-f]}
		case $Pat in
			*\[*\]*)	Raw_Patterns+="$Sig|grep -aobE -- '$Pat'"$'\n' ;;
			*)			Raw_Patterns+="$Sig|grep -aobF -- '$Pat'"$'\n' ;;
		esac
	done
	return 0
}
