_Deps_Propose_Install() {
	local Answer
	local Packages=("$@")

	[ $# -gt 0 ] || return 1

	if [ "${DEPS_YES:-0}" != "1" ]; then
		printf 'deps: proposed install: %s\n' "$*" >&2

		# Ask for confirmation on a terminal; without one, only DEPS_YES=1 installs.
		if [ -t 0 ]; then
			printf 'deps: install now? [y/N] ' >&2
			read -r Answer || Answer=""
		elif [ -e /dev/tty ]; then
			printf 'deps: install now? [y/N] ' >&2
			read -r Answer 2>/dev/null </dev/tty || Answer=""
		else
			printf 'deps: not installed (set DEPS_YES=1 to install without asking)\n' >&2
			return 1
		fi

		case "$Answer" in
		y | Y | yes | YES | Yes) ;;
		*)
			printf 'deps: skipped\n' >&2
			return 1
			;;
		esac
	fi

	Deps_Install "${Packages[@]}"
}
