# functions — HEjder function library

Isolated, per-resource modules extracted from the Sort mainline
(source: version V13.1, the most developed standalone edition),
expanded into complete standalone toolkits.

Load them in your own script with:

```bash
source functions/system/system.sh
source functions/file/file.sh
# ...
```

Note: the `system`, `ui` and `core` modules use globals defined by the main
script (option values); source the color/ui setup first or define them
yourself — or use the standalone [colors](colors/) module instead. The
`file`, `hash`, `imagemagick`, `ffmpeg`, `exif`, `deps`, `colors`, `mime`
and `compression` modules are fully standalone — no main-script globals
required.

## FreePascal layer

Every module also ships a FreePascal translation as `<module>.pas` inside
the module directory (`functions/<module>/<module>.pas`), using native FPC
libraries wherever possible (Zipper, MD5, SHA1, BaseUnix, ...). They are
standalone units compiled with:

```
fpc -Mobjfpc -Sh <unit>.pas
```

| Unit | Resource | Functions |
|---|---|---|
| [systools.pas](system/) | Process / tool discovery | `RunTool`, `HaveTool`, `First_Token` |
| [uitools.pas](ui/) | Terminal display | `Draw_Line` |
| [filetools.pas](file/) | File toolkit | `Get_File_Ext`, `Get_Base_Name`, `Name_Without_Ext`, `Get_Compound_Ext`, `File_Size`, `Human_From_Bytes`, `Get_File_Size_Human`, `Size_Unit_From_Bytes`, `Size_Unit_Name`, `Is_File`, `Is_Dir`, `Is_Symlink`, `File_Time`, `File_Perms`, `File_Owner`, `Is_Empty_File`, `Count_Files`, `Total_Size` |
| [hash.pas](hash/) | Checksums | `Hash_String`, `Hash_File`, `Hash_Verify` |
| [imagemagick.pas](imagemagick/) | Image info | `IM_Has`, `IM_Dimensions`, `IM_Format` |
| [ffmpeg.pas](ffmpeg/) | Media info | `Video_Duration`, `Duration_Tag_From_Seconds`, `Video_Duration_Tag`, `Get_Media_Info`, `Media_Title`, `Media_Camera` |
| [exif.pas](exif/) | EXIF | `ExifTool_Has`, `ExifTool_Get_Tag`, `ExifTool_Strip` |
| [deps.pas](deps/) | Init-system | `Detect_Installer`, `Ensure_Installed` |
| [colors.pas](colors/) | Colors | `C_Color_Init`, `Print_Message` |
| [mime.pas](mime/) | MIME | `Detect_MIME`, `MIME_Main`, `MIME_Sub`, `MIME_Description`, `MIME_Charset`, `Get_MIME_Best_Extension` |
| [compression.pas](compression/) | Archives | `Is_Zip_File`, `Is_Tar_Suffix`, `Get_Compound_Ext_Last`, `Archive_Main_Name`, `Archive_Extract` |
| [coretools.pas](core/) | Naming core | `Sanitize_Name`, `Underscore`, `Unique_Target` |
| [docs.pas](docs/) | Documents | `Get_Doc_Title` |

NB/This code is not tested yet!

## Modules

| Module | Resource | Functions |
|---|---|---|
| [system](system/) | System process control | `Exit`, `Break` |
| [ui](ui/) | Terminal display | `Draw_Line` |
| [file](file/) | Complete file toolkit — coreutils / file(1) | 41 functions: MIME, name/extension splitting, sizes (fork-free human sizes via `Human_From_Bytes`), timestamps, permissions, ownership, predicates |
| [hash](hash/) | Complete checksum toolkit — md5 / SHA family / crc32 / blake2 | 22 functions: per-algorithm getters, dispatcher, string hashing, verification, containment, directory diff/minus, duplicate finding |
| [imagemagick](imagemagick/) | Complete image toolkit — ImageMagick identify / magick | 20 functions: dimensions, format, colors, depth, quality, DPI, orientation, camera, GPS, actions |
| [ffmpeg](ffmpeg/) | Complete media toolkit — ffmpeg / ffprobe | 27 functions: dimensions, one-call media info (`Get_Media_Info`), codecs, container, duration, bitrate, FPS, channels, tags, actions |
| [exif](exif/) | Complete EXIF toolkit — exiftool / ImageMagick fallback | 23 functions: generic tag access, dumps, camera, lens, exposure, GPS, strip/set/copy actions |
| [deps](deps/) | Init-system for external tools — installer / privilege detection | 8 functions: detection, package mapping, install, ensure, init |
| [colors](colors/) | Complete color toolkit — ANSI colors / print helpers | 13 functions: `C_*` color variables, Print_Message/Info/Ok/Error/Warning/Log/Debug, headers, separators |
| [mime](mime/) | Complete MIME toolkit — file(1) / magic bytes / extension maps | 21 functions: type/main/sub/description/charset, magic bytes, magic detection, database-sourced MIME↔extension maps (911 extensions / 687 types), best-match extension, pattern match, type predicates |
| [compression](compression/) | Complete archive toolkit — tar / gz / bz2 / xz / zst / zip / 7z / rar | 12 functions: magic-byte type detection, integrity test, listing, extraction, main-name lookup, creation, single-file compression |
| [docs](docs/) | Documents (pdftotext / exiftool) | `Get_Doc_Title` |
| [core](core/) | Organizer core logic | `Resolve_Path_Segment`, `Parse_Arguments`, `Validate_Options`, `Perform_Action`, `Sort`, `Show_Help` |

Total: 197 shell functions in 13 modules, plus 13 FreePascal units.
