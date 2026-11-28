Show_Help() {
	Draw_Line '━'

	cat <<'EOF'
Sort.sh v2.1 - Media-Intelligent File Organizer
Organizes files using MIME information, filesystem timestamps and metadata.

USAGE
  Sort.sh [OPTIONS] FILE_OR_DIRECTORY [FILE_OR_DIRECTORY ...]

  With no operation mode, the script performs a dry run and only displays
  the planned destination. Files are not changed unless a mode is selected.

OPERATION MODES
  --mode=copy       Copy files to the calculated destination.
  --mode=move       Move files to the calculated destination.
  --mode=delete     Permanently delete the calculated destination file.
  --mode=remove     Alias for --mode=delete.
  --mode=trash      Send the calculated destination file to desktop trash.
  --mode=shred      Run shred -u -n 1 on the calculated destination file.

  Short forms:
  --copy            Same as --mode=copy.
  --move            Same as --mode=move.
  --delete          Same as --mode=delete.
  --remove          Same as --mode=remove.
  --trash           Same as --mode=trash.
  --shred           Same as --mode=shred.

  IMPORTANT:
  delete/remove/trash/shred operate on the calculated TARGET path, not
  automatically on the original source path. If source and target resolve
  to the same file, destructive operations are refused. Review the TARGET
  output carefully before selecting a destructive mode.

FILTERING AND PROCESSING
  --type=VALUE      Process only files whose MIME type contains VALUE.
                    Examples: image, video, audio, pdf, application.
  --recursive       Process files inside supplied directories, including
                    nested directories and hidden files.
  --pause=SECONDS   Wait for the specified number of seconds after each file.

DESTINATION AND NAMING
  --dirs=VALUE      Set the primary destination directory component.
  --subdirs=VALUE   Add a directory component beneath the primary directory.
  --rename=VALUE    Generate a filename (without extension) from VALUE.
  --extension=VALUE Generate the extension from VALUE.
  --title           Try to create the filename from embedded metadata:
                    application: attempts to read a PDF /Title entry
                    image:      uses date_time_original, then filesystem time
                    audio:      combines Artist, Album and Title tags
                    video:      combines Artist and Title tags
                    other:      keeps the original filename
  --replace         Allow copy/move to overwrite an existing destination.
                    Without it, a unique name such as photo-(1).jpg is used.

DYNAMIC VALUES
  Values below can be used with --dirs, --subdirs, --rename and --extension.
  Keywords are case-insensitive.

  DATE AND FILE TIMES
    year              Birth-time year (YYYY); 0000 if unavailable.
    month             Birth-time month (MM); 00 if unavailable.
    day               Birth-time day (DD); 00 if unavailable.
    year+month        Year/month path (YYYY/MM).
    year+month+day    Year/month/day path (YYYY/MM/DD).
    created           Filesystem creation-time string.
    modified          Last modification-time string.
    accessed          Last access-time string.

  FILE IDENTITY
    extension         Original extension.
    mime              Full MIME type, e.g. IMAGE/JPEG.
    mime-main         MIME major type, e.g. IMAGE or VIDEO.
    mime-sub          MIME subtype, e.g. JPEG, MP4 or PDF.
    md5 / md5sum      MD5 checksum.
    sha               SHA checksum using shasum.
    sha1              SHA-1 checksum using sha1sum.
    sha224            SHA-224 checksum using sha224sum.
    sha256            SHA-256 checksum using sha256sum.
    sha384            SHA-384 checksum using sha384sum.
    sha512            SHA-512 checksum using sha512sum.
    shasum            Checksum using shasum.
    sha1deep          Checksum using sha1deep.
    sha256deep        Checksum using sha256deep.
    sha1sum           Checksum using sha1sum.
    sha224sum         Checksum using sha224sum.
    sha256sum         Checksum using sha256sum.
    sha384sum         Checksum using sha384sum.
    sha512sum         Checksum using sha512sum.
    random            One Bash-generated random number.
    randomN           N concatenated random values, e.g. random3.

  SIZE AND MEDIA DIMENSIONS
    size              Images/videos: width x height (e.g. 1920x1080).
                      Other files: decimal file-size unit (B, KB, MB, GB, TB).
    format            Images/videos: resolution tier and orientation.
                      Other files: decimal unit name (Byte, Kilo, Mega, etc.).
    size+format       Images/videos: tier/orientation plus dimensions.
                      Other files: binary unit (B, KiB, MiB, GiB, TiB).
    format+size       Images/videos: tier/orientation plus dimensions.
                      Other files: decimal unit name followed by the value.

  Resolution tiers use the larger dimension:
    TINY, MINI, SMALLER, SMALL, MEDIUM, BIG, BIGGER, HUGE.
  Orientation is SQUARE, WIDE or HIGH.

EXAMPLES
  Preview images grouped by MIME category:
    Sort.sh --dirs=mime-main --type=image ./Downloads/*

  Move videos into year/month folders and use metadata titles:
    Sort.sh --mode=move --dirs=year+month --title --type=video ./Videos/*

  Copy images and use their SHA-256 checksum as the filename:
    Sort.sh --mode=copy --dirs=year --rename=sha256sum --type=image *.jpg

  Organize PDF files by extension and size-unit label:
    Sort.sh --mode=move --dirs=extension --subdirs=format *.pdf

  Preview a destination filename based on the original extension:
    Sort.sh --dirs=mime-main --rename=extension ./Downloads/*

DEPENDENCIES
  Required: Bash, file, coreutils, grep, sed, ffprobe (FFmpeg),
            identify (ImageMagick), and tput (ncurses/terminfo).
  Optional: trash-put for trash mode; shred for shred mode; additional
            checksum programs for the matching checksum keywords.

NOTES AND LIMITATIONS
  * Requires Bash with associative arrays and modern [[ ... ]] syntax.
  * File birth/creation times depend on filesystem support.
  * PDF title extraction is a simple text search, not a complete PDF parser.
  * Metadata extraction is best-effort and depends on the media format.
  * --jobs and --compare are accepted for compatibility but are not implemented.
  * shred cannot guarantee secure erasure on SSDs, snapshots, journals,
    copy-on-write filesystems or storage devices with wear levelling.
  * Always perform a dry run before using move, delete, trash or shred.
EOF

	Draw_Line '━'
}
