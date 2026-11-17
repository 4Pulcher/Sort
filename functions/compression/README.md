# functions/compression

> Archive toolkit - tar / gz / bz2 / xz / zst / zip / 7z / rar

A complete, standalone bag of archive tools: type detection by magic bytes (extension only as a last resort), integrity testing, listing, extraction, creation and single-file compression. `.tar.gz`/`.tgz`-style compound archives are detected by their gzip/bzip2/xz/zstd magic and delegated to `tar`, which auto-decompresses. Every function prints its result on stdout and returns non-zero on failure (127 when the needed tool is missing, 1 = file/argument problem). Missing tools are proposed for install through the deps init-system when it is loaded.

## Functions

### Detection

- `Get_Archive_Type` — tar | gzip | bzip2 | xz | zstd | zip | 7z | rar, by magic bytes
- `Archive_Is` — boolean: is the file a recognized archive

### Integrity and content

- `Archive_Test` — integrity test (rc 0 = intact, 1 = corrupt, 127 = tool missing)
- `Archive_List` — entries, one per line

### Extraction and creation

- `Archive_Extract` — extract into a directory (created when missing)
- `Archive_Main_Name` — main directory inside the archive, or the single contained file's base name (for `--rename=compressed`)
- `Archive_Create` — create an archive; format follows the extension (`.tar`, `.tar.gz`/`.tgz`, `.tar.bz2`, `.tar.xz`, `.tar.zst`, `.zip`, `.7z`)

### Single-file compression

- `Compress_File` — dispatcher: gzip | bzip2 | xz | zstd
- `Compress_Gzip`, `Compress_Bzip2`, `Compress_Xz`, `Compress_Zstd`

## Tools used

| Type | Tools |
|---|---|
| tar family | `tar` (auto-decompresses .tar.gz/.tgz/.tar.bz2/.tar.xz/.tar.zst) |
| single-file | `gzip`/`gunzip`, `bzip2`/`bunzip2`, `xz`, `zstd` |
| zip | `unzip` (test/list/extract), `zip` (create) |
| 7z | `7z` (test/list/extract/create) |
| rar | `unrar` (test/list/extract) |
