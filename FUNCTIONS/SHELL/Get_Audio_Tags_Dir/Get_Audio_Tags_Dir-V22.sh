Get_Audio_Tags_Dir() {
	local File=$1 A Y Al Sub Out

	A=$(Get_Audio_Artist "$File" 2>/dev/null)
	Y=$(Get_Audio_Year "$File" 2>/dev/null)
	Al=$(Get_Audio_Album "$File" 2>/dev/null)

	if [ -n "$Y" ] && [ -n "$Al" ]; then
		Sub="$Y - $Al"
	else
		Sub="${Y}${Al}"
	fi

	Out="$A"
	[ -n "$Sub" ] && Out="${Out:+$Out/}$Sub"

	if [ -n "$Out" ] && declare -F Sanitize_Name >/dev/null 2>&1; then
		local -a Parts
		local P Result=''
		IFS='/' read -ra Parts <<<"$Out"
		for P in "${Parts[@]}"; do
			P=$(Sanitize_Name "$P")
			[ -n "$P" ] && Result="${Result:+$Result/}$P"
		done
		Out=$Result
	fi

	[ -n "$Out" ] && printf '%s' "$Out"
}
