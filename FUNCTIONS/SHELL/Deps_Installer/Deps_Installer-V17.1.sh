Deps_Installer() {
	local Installer

	for Installer in apt-get dnf yum pacman zypper apk xbps-install; do
		if command -v "$Installer" >/dev/null 2>&1; then
			printf '%s' "$Installer"
			return 0
		fi
	done

	return 1
}
