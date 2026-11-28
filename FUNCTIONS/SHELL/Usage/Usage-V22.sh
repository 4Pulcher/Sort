Usage() {
	Print_Header "$(T 'Sort 22 - self-contained threaded organizer + magic detection, raw+fs scan')"
	Print_Message 'Usage: Sort.sh [options] <file|directory> ...'
	printf '\n'
	Print_Message 'Common starts:'
	printf '\n'
	printf '\t%s\n' 'Sort.sh --copy --replace ~/Pictures/2Sort'
	printf '\t%s\n' 'Sort.sh --move --rename=sha256sum --extension=none .'
	printf '\t%s\n' 'Sort.sh --recursive --dirs=year+month --type=image ~/Pics'
	printf '\t%s\n' 'Sort.sh --colored --jobs=8 --exif --target=~/Sorted ~/Pics'
	printf '\t%s\n' 'Sort.sh --decompress --dirs=mime ~/Archives'
	printf '\n'
	Print_Message 'Use --help for the full option list and dynamic values.'
}
