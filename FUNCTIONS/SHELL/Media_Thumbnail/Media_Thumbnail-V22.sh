Media_Thumbnail() {
	local Video=$1
	local Time=${2:-00:00:01}
	local Out=$3

	[ -f "$Video" ] && [ -n "$Out" ] || return 1
	_FF_Have ffmpeg || return 127

	timeout 60s ffmpeg -y -v error -ss "$Time" -i "$Video" -frames:v 1 -q:v 2 -- "$Out" >/dev/null 2>&1
}
