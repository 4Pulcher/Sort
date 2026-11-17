# functions/mime

> Complete MIME toolkit - file(1) / magic bytes / extension maps (v2.2)

A complete, standalone bag of MIME tools built on file(1): MIME type, main/sub parts, human description, charset, magic bytes (hex and print-string), magic-number detection, bidirectional MIME <-> extension mapping, filename-to-MIME guessing, pattern matching and main-type predicates. Every function takes a path as its first argument, prints its result on stdout and returns non-zero on failure.

Since v2.1 the extension maps are distilled from the user's MIME database: 911 extension -> MIME entries and 687 MIME -> extension entries, plus base-linux supplements (`sh`, `bash`, `xz`, `elf`, `log`) and canonical overrides (`txt`, `jpg`, `mp3`, `bin`).

## Functions

### Core getters (file(1))

- `Get_MIME_Type` — full MIME type (e.g. `image/png`)
- `Get_MIME_Main` — part before `/` (e.g. `image`)
- `Get_MIME_Sub` — part after `/` (e.g. `png`)
- `Get_MIME_Description` — human-readable description from file(1)
- `Get_MIME_Charset` — MIME encoding (us-ascii, utf-8, binary, ...)
- `Get_MIME_All` — summary block: type, main, sub, description, charset, extension, magic

### Magic bytes

- `Get_Magic_Bytes <file> [count]` — first bytes as space-separated hex (default 16)
- `Get_Magic_String <file> [count]` — first bytes as printable string (non-printables become `.`)
- `Get_MIME_By_Magic` — MIME from the magic number alone (JPEG, PNG, GIF, BMP, PDF, ZIP, gzip, bzip2, xz, 7z, RAR, ELF, DOS, WASM, SQLite, MP3, OGG, FLAC, MPEG, Matroska, MP4/ftyp, RIFF→WEBP/WAV); false for unknown magic. Uses a curated, hand-verified signature set: an external signature database was evaluated and rejected because its signatures turned out corrupted (e.g. PNG listed without the `PNG` bytes, PDF reduced to one stray byte) and riddled with junk 1–2 byte signatures that steal matches.

### MIME <-> extension mapping

- `Get_MIME_Best_Extension` - best matching extension: exact table, then x- variants, then own ext when it maps to the type, then main-type default, then original
- `Get_MIME_Extension` — canonical extension for the file's MIME type (687 types, database-sourced)
- `Get_Extension_MIME <ext>` — MIME for an extension (leading dot and case ignored; 911 extensions, database-sourced)
- `Get_Name_MIME <name>` — MIME guessed from a filename alone, no file needed

### Matching and predicates

- `MIME_Match <file> <pattern>` — shell-wildcard match: `image/*`, `*/png`, `text/plain`
- `MIME_Is_Text` / `MIME_Is_Binary`
- `MIME_Is_Image` / `MIME_Is_Video` / `MIME_Is_Audio`
- `MIME_Is_Archive` — zip, gzip, bzip2, xz, 7z, rar, tar, iso, cpio
- `MIME_Is_Document` — pdf, ps, rtf, MS Office, OpenXML, OpenDocument

Total: 20 functions.
