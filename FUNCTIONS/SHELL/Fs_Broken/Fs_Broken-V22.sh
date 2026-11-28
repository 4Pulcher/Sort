Fs_Broken() {
	local Hit=$1 Size=$2 Skip=$3 I
	if [ $(( Hit + Size )) -gt $(( FsPStart[$Skip] + FsPSize[$Skip] )) ]; then
		return 0
	fi
	for (( I = 0; I < ${#FsPStart[@]}; I++ )); do
		[ "$I" = "$Skip" ] && continue
		if [ "$Hit" -lt $(( FsPStart[$I] + FsPSize[$I] )) ] && \
		   [ $(( Hit + Size )) -gt "${FsPStart[$I]}" ]; then
			return 0
		fi
	done
	return 1
}
