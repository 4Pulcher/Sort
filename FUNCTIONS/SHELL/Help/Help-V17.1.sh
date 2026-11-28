Help() {
	Print_Header "$(T 'Sort 17.1 - self-contained threaded organizer')"
	Print_Message 'Sorts files into a dynamic directory tree built from MIME, dates,'
	Print_Message 'sizes, media dimensions, checksums and metadata titles.'
	printf '\n'
	Print_Header "$(T 'Modes')" '='
	printf '\t%s\n' "$(T '(default)          Preview only - print source <=> target')"
	printf '\t%s\n' "$(T '--copy             Copy every file to its sorted location')"
	printf '\t%s\n' "$(T '--move             Move every file to its sorted location')"
	printf '\t%s\n' "$(T '--remove           Remove the file at the calculated TARGET path')"
	printf '\t%s\n' "$(T '--delete           Alias for --remove')"
	printf '\t%s\n' "$(T '--trash            Send the calculated target to the desktop trash')"
	printf '\t%s\n' "$(T '--shred            Run shred -u -n 1 on the calculated target')"
	printf '\t%s\n' "$(T '--mode=VALUE       Long form of any mode above (copy/move/...)')"
	printf '\n'
	Print_Message 'IMPORTANT: remove/delete/trash/shred act on the calculated TARGET'
	Print_Message 'path, not on the source. Source = target is refused. Review the'
	Print_Message 'preview output before using a destructive mode.'
	printf '\n'
	Print_Header "$(T 'Filtering and processing')" '='
	printf '\t%s\n' "$(T '--type=VALUE       Only files whose MIME type contains VALUE')"
	printf '\t%s\n' "$(T '                   (image, video, audio, pdf, application, ...)')"
	printf '\t%s\n' "$(T '--recursive        Walk supplied directories to full depth')"
	printf '\t%s\n' "$(T '--hidden           Include hidden files and directories')"
	printf '\t%s\n' "$(T '--links            Include symbolic links')"
	printf '\t%s\n' "$(T '--pause=SECONDS    Wait after each file')"
	printf '\t%s\n' "$(T '--jobs=N           Thread pool size (default: nproc, min 1)')"
	printf '\n'
	Print_Header "$(T 'Destination and naming')" '='
	printf '\t%s\n' "$(T '--target=DIR       Base directory of the sorted tree (default: .)')"
	printf '\t%s\n' "$(T '--dirs=LIST        Primary directory components (default: mime)')"
	printf '\t%s\n' "$(T '--subdirs=LIST     Directory components beneath the primary')"
	printf '\t%s\n' "$(T '--rename=VALUE     Generate the filename (without extension)')"
	printf '\t%s\n' "$(T '--extension=VALUE  Generate the extension (none/mime/mime-sub/mime-ext/...)')"
	printf '\t%s\n' "$(T '--title            Filename from embedded metadata (PDF /Title,')"
	printf '\t%s\n' "$(T '                   image EXIF date, audio/video tags)')"
	printf '\t%s\n' "$(T '--replace          Overwrite existing targets, else unique ~(N) name')"
	printf '\n'
	Print_Header "$(T 'EXIF / metadata')" '='
	printf '\t%s\n' "$(T '--exif             Add <Camera>/<YYYY-MM-DD> levels for images')"
	printf '\t%s\n' "$(T '--strip            Strip EXIF/GPS metadata from targets after copy/move')"
	printf '\n'
	Print_Header "$(T 'Archives')" '='
	printf '\t%s\n' "$(T '--decompress       Extract archives to a temp dir and sort the contents')"
	printf '\t%s\n' "$(T '                   (the archive itself is deleted after success;')"
	printf '\t%s\n' "$(T '                   --trash / --shred apply that fate to it instead)')"
	printf '\t%s\n' '--rename=compressed  Name = main dir / single file inside the archive'
	printf '\n'
	Print_Header "$(T 'Output and safety')" '='
	printf '\t%s\n' "$(T '--colored          Force colored output (auto-detected on a tty)')"
	printf '\t%s\n' "$(T '--colors           Alias for --colored')"
	printf '\t%s\n' "$(T '--quiet            Per-file details off; summary only')"
	printf '\t%s\n' "$(T '--verbose          Per-file details on (default)')"
	printf '\t%s\n' "$(T '--stats            Print the summary (default)')"
	printf '\t%s\n' "$(T '--log=FILE         Append one line per action to FILE')"
	printf '\t%s\n' "$(T '--undo[=FILE]      Write an undo script (default: sort_undo_<time>.sh)')"
	printf '\t%s\n' "$(T '--usage            Short reminder')"
	printf '\t%s\n' "$(T '--help             This help')"
	printf '\t%s\n' "$(T '--version          Print the version')"
	printf '\t%s\n' "$(T '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)')"
	printf '\t%s\n' "$(T '--lang             Print the language list')"
	printf '\n'
	Print_Header "$(T 'Dynamic values')" '='
	Print_Message 'Case-insensitive keywords for --dirs, --subdirs, --rename and'
	Print_Message '--extension. Unknown words become literal names. Lists are joined'
	Print_Message 'with + or , (e.g. --dirs=year+month --subdirs=format,size).'
	printf '\n'
	Print_Message 'Date and file times:'
	printf '\t%s\n' 'year month day year+month year+month+day'
	printf '\t%s\n' 'created modified accessed'
	printf '\n'
	Print_Message 'File identity:'
	printf '\t%s\n' 'extension mime (text/plain) mime-main (TEXT) mime-sub (plain)'
	printf '\t%s\n' 'mime-ext (jpg - best matching extension for the MIME type)'
	printf '\t%s\n' 'compressed (main dir / single file inside an archive)'
	printf '\t%s\n' 'md5|md5sum sha1 sha224 sha256 sha384 sha512 sha|shasum b2 crc32'
	printf '\t%s\n' 'random randomN (N concatenated random values, e.g. random3)'
	printf '\n'
	Print_Message 'Size and media dimensions:'
	printf '\t%s\n' 'size        images/videos: WxH - others: human size (4.0M)'
	printf '\t%s\n' 'format      images/videos: TIER/ORIENTATION - others: unit name'
	printf '\t%s\n' 'size+format / format+size   both, in either order'
	printf '\t%s\n' 'duration    videos: HH-MM-SS'
	printf '\n'
	Print_Message 'Resolution tiers use the larger dimension:'
	printf '\t%s\n' 'TINY <64, MINI <128, SMALLER <320, SMALL <640, MEDIUM <1280,'
	printf '\t%s\n' 'BIG <1920, BIGGER <3840, HUGE otherwise'
	printf '\t%s\n' 'Orientation: SQUARE (w=h), WIDE (w>h), HIGH (h>w)'
	printf '\n'
	Print_Message 'Metadata (needs exiftool):'
	printf '\t%s\n' 'camera      EXIF camera as directory tag'
	printf '\t%s\n' 'exifdate    EXIF capture date as YYYY-MM-DD'
	printf '\t%s\n' 'title       embedded title (PDF /Title, media tags, EXIF date)'
	printf '\n'
	Print_Header "$(T 'Examples')" '='
	printf '\t%s\n' 'Sort.sh --dirs=mime-main --type=image ./Downloads/*'
	printf '\t%s\n' 'Sort.sh --mode=move --dirs=year+month --title --type=video ~/V'
	printf '\t%s\n' 'Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg'
	printf '\t%s\n' 'Sort.sh --mode=trash --recursive --type=audio --pause=1 ~/Music'
	printf '\n'
	printf '\n'
	Print_Header "$(T 'Languages')" '='
	Lang_List
	printf '\n'
	Print_Message 'Missing tools are proposed for install on first use (init-system).'
}
