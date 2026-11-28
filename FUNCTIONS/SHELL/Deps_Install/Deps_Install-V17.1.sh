Deps_Install() {
	local Installer Priv
	local Flags=()
	local Cmd=()

	[ $# -gt 0 ] || return 1

	Installer=$(Deps_Installer) || {
		printf '%s\n' "$(T 'deps: no supported package manager found')" >&2
		return 1
	}

	Priv=$(Deps_Priv) || {
		printf '%s\n' "$(T 'deps: no way to gain root (run as root or install sudo)')" >&2
		return 1
	}

	case "$Installer" in
	apt-get) Flags=(install -y) ;;
	dnf) Flags=(install -y) ;;
	yum) Flags=(install -y) ;;
	pacman) Flags=(-S --noconfirm --needed) ;;
	zypper) Flags=(--non-interactive install) ;;
	apk) Flags=(add) ;;
	xbps-install) Flags=(-Sy) ;;
	*) return 1 ;;
	esac

	Cmd=("$Installer" "${Flags[@]}" "$@")

	if [ "$(id -u 2>/dev/null)" = "0" ]; then
		"${Cmd[@]}"
	elif [ "$Priv" = "sudo" ]; then
		sudo "${Cmd[@]}"
	else
		su -c "${Cmd[*]}"
	fi
}
