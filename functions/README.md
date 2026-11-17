# functions — HEjder function library

Isolated, per-resource modules extracted from the Sort mainline
(source: version V13.1, the most developed standalone edition).

Load them in your own script with:

```bash
source functions/system/system.sh
source functions/file/file.sh
# ...
```

Note: the modules use globals defined by the main script (ANSI color variables,
option values); source the color/ui setup first or define them yourself.

## Modules

| Module | Resource | Functions |
|---|---|---|
| [system](system/) | System process control | `Exit`, `Break` |
| [ui](ui/) | Terminal display | `Draw_Line` |
| [file](file/) | File attributes via coreutils / file(1) | `Get_MIME`, `Get_File_Name`, `Get_File_Ext`, `Get_File_Size`, `Get_File_Birth`, `Get_File_Creation_Time`, `Get_File_Access_Time`, `Get_File_Modification_Time`, `Get_Date_Part` |
| [hash](hash/) | Checksums (md5sum / sha*sum) | `Get_MD5Sum`, `Get_SHA_Keys`, `Get_SHA256Sum` |
| [imagemagick](imagemagick/) | Images via ImageMagick | `Get_Image_WxH`, `Get_Image_Meta`, `Get_WxH_Format` |
| [ffmpeg](ffmpeg/) | Audio & video via ffmpeg/ffprobe | `Get_Media_WxH`, `Get_Audio_Info`, `Get_Video_Title` |
| [docs](docs/) | Documents (pdftotext / exiftool) | `Get_Doc_Title` |
| [core](core/) | Organizer core logic | `Resolve_Path_Segment`, `Parse_Arguments`, `Validate_Options`, `Perform_Action`, `Sort`, `Show_Help` |

Total: 28 functions in 8 modules.
