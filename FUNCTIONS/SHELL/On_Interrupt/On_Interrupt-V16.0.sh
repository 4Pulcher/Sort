On_Interrupt() {
	Print_Error 'Interrupted - stopping running jobs...'
	jobs -rp | xargs -r kill 2>/dev/null
	wait 2>/dev/null
	exit 130
}
