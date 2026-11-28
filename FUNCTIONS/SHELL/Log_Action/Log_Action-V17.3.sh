Log_Action() {
	[ -n "$LogFile" ] || return 0
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LogFile"
}
