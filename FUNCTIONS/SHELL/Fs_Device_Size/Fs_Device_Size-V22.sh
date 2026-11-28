Fs_Device_Size() {
	local S
	S=$(stat -c %s -- "$1" 2>/dev/null)
	[ -n "$S" ] && [ "$S" -gt 0 ] && { printf '%s' "$S"; return 0; }
	S=$(blockdev --getsize64 -- "$1" 2>/dev/null)
	[ -n "$S" ] && [ "$S" -gt 0 ] && { printf '%s' "$S"; return 0; }
	return 1
}
