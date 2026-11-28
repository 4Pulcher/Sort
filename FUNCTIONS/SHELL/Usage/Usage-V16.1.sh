Usage() {
	Print_Header 'Sort 16.1 - threaded file organizer'
	Print_Message 'Usage: Sort.sh [options] <file|directory> ...'
	printf '\n'
	Print_Message 'Common starts:'
	printf '\n'
	printf '\t%s\n' 'Sort.sh --copy --replace ~/Pictures/2Sort'
	printf '\t%s\n' 'Sort.sh --move --rename=sha256sum --extension=none .'
	printf '\t%s\n' 'Sort.sh --colored --jobs=8 --exif ~/Pictures'
	printf '\n'
	Print_Message 'Use --help for the full option list.'
}
