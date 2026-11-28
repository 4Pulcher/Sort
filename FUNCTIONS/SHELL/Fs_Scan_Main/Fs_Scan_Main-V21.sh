Fs_Scan_Main() {
	local Dev=$1 Forms=$2 Mode=$3 OutBase=$4 LogF=$5
	case $Mode in
	Move | Remove | Trash | Shred)
		Print_Error "$(Tf 'SCAN: --scan supports dummy and copy only (mode '\''%s'\'' refused)' "$(printf %s "$Mode" | tr '[:upper:]' '[:lower:]')")"
		return 64 ;;
	esac
	local -A FmtSel
	local Tok Forms_L=''
	Forms=${Forms:-all}
	for Tok in ${Forms//,/ }; do
		Tok=$(printf '%s' "$Tok" | tr '[:upper:]' '[:lower:]')
		case $Tok in ext2 | ext3 | ext4) Tok=ext ;; hfs+ | hfsx | hfsplus) Tok=hfs ;; esac
		if [[ " $Fs_Formats " != *" $Tok "* ]]; then
			Print_Error "$(Tf 'SCAN: unknown filesystem format '\''%s'\'' (known: %s)' "$Tok" "${Fs_Formats// /,}")"
			return 64
		fi
		FmtSel[$Tok]=1
	done
	[ ${#FmtSel[@]} -eq 0 ] && FmtSel[all]=1
	Raw_Scan_Init
	local Fsize
	Fsize=$(Fs_Device_Size "$Dev")
	if [ -z "$Fsize" ]; then
		Print_Error "$(Tf 'SCAN: cannot determine size of %s' "$Dev")"
		return 66
	fi

	# --- phase 1: partitions (listed from MBR/GPT, lost via probe) ---
	Fs_Listed "$Dev" "$Fsize"
	local NL=${#FsLStart[@]}
	FsPStart=() FsPSize=() FsPFs=() FsPStatus=()
	local I Off Tok2 Est Hex Base Win=$(( 1024 * 1024 )) Tail=4096
	local ListT=$(mktemp)
	for (( I = 0; I < NL; I++ )); do
		Fs_Probe "$Dev" "${FsLStart[$I]}"
		printf '%s|%s|%s|%s\n' "${FsLStart[$I]}" "${FsLSize[$I]}" "${Fs_Tok:-unknown}" 'listed' >>"$ListT"
	done
	Base=0
	while [ "$Base" -lt "$Fsize" ]; do
		Hex=$(Raw_Head_Hex "$Dev" "$Base" $(( Win + Tail )))
		[ -n "$Hex" ] || break
		for (( Off = Base; Off < Base + Win && Off < Fsize; Off += 512 )); do
			Fs_Inside_Listed "$Off" "$NL" && continue
			Fs_Probe_Hex "${Hex:$(( ( Off - Base ) * 2 )):2400}"
			[ -n "$Fs_Tok" ] || continue
			Est=$Fsize
			for (( I = 0; I < NL; I++ )); do
				if [ "${FsLStart[$I]}" -gt "$Off" ] && [ "${FsLStart[$I]}" -lt "$Est" ]; then
					Est=${FsLStart[$I]}
				fi
			done
			printf '%s|%s|%s|%s\n' "$Off" "$(( Est - Off ))" "$Fs_Tok" 'lost' >>"$ListT"
		done
		Base=$(( Base + Win ))
	done
	local P N=0
	while IFS='|' read -r Off Est Tok2 Stat; do
		FsPStart[$N]=$Off; FsPSize[$N]=$Est
		FsPFs[$N]=$Tok2; FsPStatus[$N]=$Stat
		N=$(( N + 1 ))
	done <"$ListT"
	rm -f "$ListT"
	local NList=0
	for (( I = 0; I < N; I++ )); do
		[ "${FsPStatus[$I]}" = listed ] && NList=$(( NList + 1 ))
	done
	printf 'SCAN: %s\n' "$Dev"
	for (( I = 0; I < N; I++ )); do
		if [ "${FsPStatus[$I]}" = lost ]; then
			printf '  part %d: 0x%012x %s ~%s %s %s\n' $(( I + 1 )) \
				"${FsPStart[$I]}" "${FsPStart[$I]}" "${FsPSize[$I]}" \
				"${FsPFs[$I]}" "${FsPStatus[$I]}"
		else
			printf '  part %d: 0x%012x %s %s %s %s\n' $(( I + 1 )) \
				"${FsPStart[$I]}" "${FsPStart[$I]}" "${FsPSize[$I]}" \
				"${FsPFs[$I]}" "${FsPStatus[$I]}"
		fi
	done
	printf 'SCAN: %d partitions found (%d listed, %d lost)\n' "$N" "$NList" $(( N - NList ))

	# --- phase 2: per-partition signature scan (V20 engine, bounded) ---
	local Cap=$(( 5 * 1024 * 1024 )) Lead=32800
	local Tmp_Raw_Hex=$(mktemp) Hits=$(mktemp) Sorted=$(mktemp)
	local Size Exact NextAllowed Name Exts Ext Head Hit Sig Count Scanned=0
	local Total=0 Lo Hi Out Broken OutDir RStart RLen
	[ "$Mode" = Copy ] && mkdir -p -- "$OutBase/FS-CARVE"
	for (( I = 0; I < N; I++ )); do
		if [ -z "${FmtSel[all]:-}" ] && [ -z "${FmtSel[${FsPFs[$I]}]:-}" ]; then
			continue
		fi
		[ "${FsPFs[$I]}" = unknown ] && continue
		Lo=${FsPStart[$I]}; Hi=$(( Lo + FsPSize[$I] ))
		: >"$Hits"
		Base=$Lo
		while [ "$Base" -lt "$Hi" ]; do
			RStart=$Base RLen=$Win
			if [ "$Base" -gt "$Lo" ]; then RStart=$(( Base - Lead )); RLen=$(( Win + Lead )); fi
			Raw_Head_Hex "$Dev" "$RStart" "$RLen" >"$Tmp_Raw_Hex"
			Raw_Scan_Grep "$RStart" | awk -F'|' -v lo="$Lo" -v hi="$Hi" \
				'{ if ($1 >= lo && $1 < hi) print }' >>"$Hits"
			Base=$(( Base + Win ))
		done
		# hit|name|sig, ties by name (same tie-break as the Python edition)
		while IFS='|' read -r H2 S2; do
			printf '%s|%s|%s\n' "$H2" "${RawName[$S2]}" "$S2"
		done <"$Hits" | sort -t'|' -k1,1n -k2,2 -u >"$Sorted"
		printf 'SCAN-PART %d %s 0x%012x %s\n' $(( I + 1 )) "${FsPFs[$I]}" "$Lo" "${FsPSize[$I]}"
		Count=0 NextAllowed=$Lo
		while IFS='|' read -r Hit Name Sig; do
			case $Name in *filesystem* | 'Linux swap area') continue ;; esac
			[ "$Hit" -ge "$NextAllowed" ] || continue
			Exts=${RawExts[$Sig]}
			Ext=${Exts%%,*}; [ -n "$Ext" ] || Ext=bin
			Head=$(Raw_Head_Hex "$Dev" "$Hit" "$Win")
			read -r Size Exact <<< "$(Raw_Carve_Size "$Head" "$Name" "$Cap")"
			if [ "$Exact" = exact ]; then NextAllowed=$(( Hit + Size )); else NextAllowed=$(( Hit + 1 )); fi
			Broken=''
			Fs_Broken "$Hit" "$Size" "$I" && Broken=', broken'
			Count=$(( Count + 1 )); Total=$(( Total + 1 ))
			printf '  hit: 0x%012x %s %s -> %s (carve %s bytes%s%s)\n' \
				"$Hit" "$Hit" "$Name" "$Ext" "$Size" \
				"$([ "$Exact" = exact ] || printf ', capped')" "$Broken"
			if [ "$Mode" = Copy ]; then
				OutDir=$(printf '%s/FS-CARVE/p%d-%012x' "$OutBase" $(( I + 1 )) "$Lo")
				while :; do
					mkdir -p -- "$OutDir"
					Out=$(printf '%s/%012x.%s' "$OutDir" "$Hit" "$Ext")
					if dd if="$Dev" of="$Out" bs=64k iflag=skip_bytes,count_bytes \
						skip=$Hit count=$Size 2>/dev/null && [ -s "$Out" ]; then
						break
					fi
					printf 'SCAN: out of space at %s\n' "$OutDir"
					printf 'SCAN: new target directory (empty = abort): '
					if ! read -r OutDir < /dev/tty 2>/dev/null || [ -z "$OutDir" ]; then
						Print_Error "$(T 'SCAN: copy aborted by user')"
						return 65
					fi
					OutDir=$(printf '%s/FS-CARVE/p%d-%012x' "$OutDir" $(( I + 1 )) "$Lo")
				done
				printf '  carved: %s\n' "$Out"
				if [ -n "$LogF" ]; then
					printf '{"action": "carved", "src": "%s@%s", "dst": "%s", "part": %d%s}\n' \
						"$Dev" "$Hit" "$Out" $(( I + 1 )) \
						"$([ -n "$Broken" ] && printf ', "broken": true')" >>"$LogF"
				fi
			fi
		done <"$Sorted"
		Scanned=$(( Scanned + 1 ))
		printf 'SCAN-PART %d: %d signatures found\n' $(( I + 1 )) "$Count"
	done
	rm -f "$Tmp_Raw_Hex" "$Hits" "$Sorted"
	printf 'SCAN: done, %d signatures in %d partitions\n' "$Total" "$Scanned"
	return 0
}
