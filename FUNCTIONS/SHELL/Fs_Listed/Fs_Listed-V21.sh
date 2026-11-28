Fs_Listed() {
	local Dev=$1 Fsize=$2 H G I Tb Lba Nsec Start Size Elba Nent Esz E K First Last Guid
	H=$(Raw_Head_Hex "$Dev" 0 512)
	[ "${H:1020:4}" = '55aa' ] || return 0
	FsLStart=() FsLSize=()
	local -a TbArr=()
	for I in 0 1 2 3; do
		TbArr[$I]=$(( 16#${H:$(( ( 446 + 16 * I + 4 ) * 2 )):2} ))
	done
	if [ "${TbArr[0]}" = 238 ] || [ "${TbArr[1]}" = 238 ] || \
	   [ "${TbArr[2]}" = 238 ] || [ "${TbArr[3]}" = 238 ]; then
		G=$(Raw_Head_Hex "$Dev" 512 512)
		if [ "${G:0:16}" = '4546492050415254' ]; then
			Elba=$(Fs_Le64 "$G" 144)
			Nent=$(Fs_Le32 "$G" 160)
			Esz=$(Fs_Le32 "$G" 168)
			if [ "$Esz" -ge 128 ] && [ "$Nent" -gt 0 ] && \
			   [ $(( Nent * Esz )) -le $(( 4 * 1024 * 1024 )) ]; then
				G=$(Raw_Head_Hex "$Dev" $(( Elba * 512 )) $(( Nent * Esz )))
				for (( K = 0; K < Nent; K++ )); do
					E=$(( K * Esz * 2 ))
					Guid=${G:$E:32}
					[ -n "$(printf '%s' "$Guid" | tr -d '0')" ] || continue
					First=$(Fs_Le64 "$G" $(( E + 64 )))
					Last=$(Fs_Le64 "$G" $(( E + 80 )))
					[ "$Last" -lt "$First" ] && continue
					Start=$(( First * 512 ))
					Size=$(( ( Last - First + 1 ) * 512 ))
					if [ "$Size" -gt 0 ] && [ $(( Start + Size )) -le "$Fsize" ]; then
						FsLStart[${#FsLStart[@]}]=$Start
						FsLSize[${#FsLSize[@]}]=$Size
					fi
				done
			fi
			return 0
		fi
	fi
	for I in 0 1 2 3; do
		Tb=${TbArr[$I]}
		case $Tb in 0 | 5 | 15 | 85 | 238) continue ;; esac
		Lba=$(Fs_Le32 "$H" $(( ( 446 + 16 * I + 8 ) * 2 )))
		Nsec=$(Fs_Le32 "$H" $(( ( 446 + 16 * I + 12 ) * 2 )))
		[ "$Nsec" -gt 0 ] || continue
		Start=$(( Lba * 512 ))
		Size=$(( Nsec * 512 ))
		if [ $(( Start + Size )) -le "$Fsize" ]; then
			FsLStart[${#FsLStart[@]}]=$Start
			FsLSize[${#FsLSize[@]}]=$Size
		fi
	done
	return 0
}
