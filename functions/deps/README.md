# functions/deps

> Init-system for external tools - installer / privilege detection

An init-system for tools outside base-linux: detects the system package manager (apt-get, dnf, yum, pacman, zypper, apk, xbps-install) and the privilege escalator (root, sudo, su). On first use of a missing external tool it proposes the installation, asks for confirmation and runs it. Set `DEPS_YES=1` to install without asking. Every function returns true (0) on success and false (non-zero) otherwise.

The `imagemagick`, `ffmpeg` and `exif` modules call `Deps_Ensure` automatically (only when this module is loaded) whenever their external tool is missing.

## Functions

### Detection

- `Deps_Has <tool>` — predicate: is the tool on PATH?
- `Deps_Missing <tool>...` — print the missing ones; false when at least one is missing
- `Deps_Installer` — print the detected package manager (apt-get / dnf / yum / pacman / zypper / apk / xbps-install)
- `Deps_Priv` — print the privilege escalator: nothing (already root), `sudo` or `su`

### Mapping and installation

- `Deps_Package <tool> [installer]` — map a tool to its package name per distro (e.g. exiftool → `libimage-exiftool-perl` on apt, `perl-Image-ExifTool` on dnf)
- `Deps_Install <package>...` — run the installer with the right privilege prefix
- `Deps_Ensure <tool> [package]` — true when the tool is present, otherwise propose + install + re-check
- `Deps_Init <tool[:package]>...` — init-system entry point: check a whole list, propose one single batch install for everything missing, true/false

## Usage

```bash
source functions/deps/deps.sh
source functions/imagemagick/imagemagick.sh

Deps_Init ffprobe identify exiftool || echo "some tools are still missing"
Get_Image_Width photo.jpg   # proposes ImageMagick install on first use
```

Total: 8 functions.
