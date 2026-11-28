Magic_Detect() {
	local H=${1,,} Key Val Name Exts Pat Off Concrete Score Best BestScore
	# MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376
	if [ "${#H}" -ge 754 ] && [ "${H:0:2}" = '47' ] && [ "${H:376:2}" = '47' ] && [ "${H:752:2}" = '47' ]; then
		printf 'video/mp2t|MPEG-TS|ts,m2ts,mts'
		return 0
	fi
	Best='' BestScore=-1
	for Key in "${!Magic[@]}"; do
		Val=${Magic[$Key]}
		IFS='|' read -r Name Exts Pat Off <<< "$Val"
		Off=${Off:-0}
		if Magic_Match "$H" "$Off" "$Pat"; then
			Concrete=${Pat//\?/}
			Score=$(( ${#Concrete} * 1000 + ${#Pat} ))
			if [ "$Score" -gt "$BestScore" ]; then
				BestScore=$Score
				Best="$Key|$Name|$Exts"
			fi
		fi
	done
	[ -n "$Best" ] || return 1
	printf '%s' "$Best"
}
