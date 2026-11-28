Media_Extract_Audio() {
	local In=$1
	local Out=$2

	[ -f "$In" ] && [ -n "$Out" ] || return 1
	_FF_Have ffmpeg || return 127

	timeout 600s ffmpeg -y -v error -i "$In" -vn -acodec copy -- "$Out" >/dev/null 2>&1
}
