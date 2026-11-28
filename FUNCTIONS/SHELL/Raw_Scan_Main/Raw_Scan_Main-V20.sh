Raw_Scan_Main() {
	local Dev=$1 Mode=$2 OutBase=$3 LogF=$4
	case $Mode in
	Move | Remove | Trash | Shred)
		Print_Error "$(Tf 'RAW-SCAN: --scan-raw supports dummy and copy only (mode '\''%s'\'' refused)' "$(printf %s "$Mode" | tr '[:upper:]' '[:lower:]')")"
		return 64 ;;
	esac
	Raw_Scan_Init
	Tmp_Raw_Hex=$(mktemp)
	local Win=$(( 1024 * 1024 )) Lead=32800 Base=0 Hit Sig Name Exts Ext
	local Size Exact Next=0 Count=0 List Out Head Cap=$(( 5 * 1024 * 1024 ))
	[ "$Mode" = Copy ] && mkdir -p -- "$OutBase/RAW-CARVE"
	printf 'RAW-SCAN: %s\n' "$Dev"
	List=$(mktemp)
	while :; do
		local Start=$Base Len=$Win
		[ $Base -gt 0 ] && { Start=$(( Base - Lead )); Len=$(( Win + Lead )); }
		dd if="$Dev" bs=64k iflag=skip_bytes,count_bytes \
			skip=$Start count=$Len 2>/dev/null |
			od -An -v -tx1 | tr -d ' \n' >"$Tmp_Raw_Hex"
		local Got
		Got=$(wc -c <"$Tmp_Raw_Hex")
		Got=$(( Got / 2 ))
		Raw_Scan_Grep "$Start" >>"$List"
		Base=$(( Base + Win ))
		[ "$Got" -lt "$Len" ] && break
		[ "$Got" -eq 0 ] && break
	done
	sort -t'|' -k1,1n -u "$List" >"$List.sorted"
	while IFS='|' read -r Hit Sig; do
		[ "$Hit" -ge "$Next" ] || continue
		Name=${RawName[$Sig]}
		Exts=${RawExts[$Sig]}
		Ext=${Exts%%,*}
		[ -n "$Ext" ] || Ext=bin
		Head=$(Raw_Head_Hex "$Dev" "$Hit" "$Win")
		read -r Size Exact <<< "$(Raw_Carve_Size "$Head" "$Name" "$Cap")"
		[ "$Exact" = exact ] && Next=$(( Hit + Size )) || Next=$(( Hit + 1 ))
		Count=$(( Count + 1 ))
		printf '  hit: 0x%012x %s %s -> %s (carve %s bytes%s)\n' \
			"$Hit" "$Hit" "$Name" "$Ext" "$Size" \
			"$([ "$Exact" = exact ] || printf ', capped')"
		if [ "$Mode" = Copy ]; then
			Out=$(printf '%s/RAW-CARVE/%012x.%s' "$OutBase" "$Hit" "$Ext")
			dd if="$Dev" of="$Out" bs=64k iflag=skip_bytes,count_bytes \
				skip=$Hit count=$Size 2>/dev/null
			printf '  carved: %s\n' "$Out"
			[ -n "$LogF" ] && printf '{"action": "carved", "src": "%s@%s", "dst": "%s"}\n' \
				"$Dev" "$Hit" "$Out" >>"$LogF"
		fi
	done <"$List.sorted"
	rm -f "$List" "$List.sorted" "$Tmp_Raw_Hex"
	printf 'RAW-SCAN: %s signatures found\n' "$Count"
	return 0
}
