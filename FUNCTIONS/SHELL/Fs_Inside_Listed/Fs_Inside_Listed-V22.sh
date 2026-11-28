Fs_Inside_Listed() {
	local Off=$1 N=$2 I
	for (( I = 0; I < N; I++ )); do
		if [ "$Off" -ge "${FsLStart[$I]}" ] && [ "$Off" -lt $(( FsLStart[$I] + FsLSize[$I] )) ]; then
			return 0
		fi
	done
	return 1
}
