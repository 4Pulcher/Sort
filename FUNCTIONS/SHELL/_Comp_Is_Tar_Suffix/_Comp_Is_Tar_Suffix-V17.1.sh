_Comp_Is_Tar_Suffix() {
	local Base=${1##*/}
	Base=${Base,,}

	case "$Base" in
	*.tar.gz | *.tgz | *.tar.bz2 | *.tbz2 | *.tbz | *.tar.xz | *.txz | *.tar.zst | *.tzst) return 0 ;;
	*) return 1 ;;
	esac
}
