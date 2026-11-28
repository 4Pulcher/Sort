Tf() {
	local Tpl
	Tpl=$(T "$1")
	shift
	printf "$Tpl" "$@"
}
