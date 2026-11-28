Media_Strip_Metadata() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_FF_Have ffmpeg || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -map_metadata -1 -c copy -- "$Out" >/dev/null 2>&1
}
