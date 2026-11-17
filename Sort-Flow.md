# Sort.sh V17.3 — program flow diagram

The actual control flow of the main `Sort.sh` (V17.3), traced from the code:
`Main` → `Parse_Arguments` → `Validate_Options` → `Deps_Init` → `Collect_Files`
→ `Run_Threads` (bounded job pool → `Process_File` per file) → `Summary`.

## Mermaid diagram

```mermaid
flowchart TD
    START([Start: ./Sort.sh args...]) --> NOARGS{any arguments?}
    NOARGS -- "no" --> USAGE[Usage / --usage] --> THANKS([Thanks for using HEjder scripts!])
    NOARGS -- "yes" --> PARSE[Parse_Arguments<br/>--lang --colored --jobs=N --mode/-copy/-move/<br/>--remove/-trash/-shred --dirs= --subdirs=<br/>--rename= --extension= --type= --recursive<br/>--hidden --links --exif --strip --title<br/>--decompress --log= --undo --pause= --replace --target=]

    PARSE --> VALIDATE{Validate_Options<br/>specs + mode + lang OK?}
    VALIDATE -- "no" --> ERR1[Print_Error + help hint] --> THANKS
    VALIDATE -- "yes" --> DEPS{--quiet?}
    DEPS -- "no" --> DEPSINIT[Deps_Init - init-system:<br/>identify ffprobe + exiftool when EXIF/strip/title/undo<br/>+ tar gzip zip bzip2 xz zstd 7z unrar when --decompress<br/>proposes install of missing tools]
    DEPS -- "yes" --> PREP
    DEPSINIT --> PREP[Prepare_Optional_Output<br/>open --log=FILE, create --undo script]

    PREP --> COLLECT[Collect_Files - build the Targets array<br/>find: -maxdepth 1 unless --recursive<br/>prune .* unless --hidden, symlinks with --links]
    COLLECT --> EMPTY{Targets empty?}
    EMPTY -- "yes" --> WARN[Print_Warning: Nothing to treat] --> THANKS
    EMPTY -- "no" --> BANNER[Draw_Line + header:<br/>N file(s), mode, jobs]

    BANNER --> POOL[Run_Threads - bounded job pool<br/>while running jobs >= Max_Jobs: wait -n<br/>spawn subshell per file: Process_File + status tag]

    POOL --> PF{Process_File per file}
    PF -- "not a regular file" --> F1[FAILED]
    PF --> MIME{MIME type detected?}
    MIME -- "no" --> F2[FAILED]
    MIME -- "yes" --> TYPEF{--type= matches MIME?}
    TYPEF -- "no" --> SKIP1[SKIPPED]
    TYPEF -- "yes" --> ARCH{--decompress and archive?}
    ARCH -- "yes" --> PARCH[Process_Archive:<br/>depth < 8? test archive - mktemp -d - extract<br/>sort contents with copy semantics<br/>then mode on the archive itself:<br/>preview / delete / trash / shred]
    ARCH -- "no" --> DIRS[DirPart: --dirs= segments or MIME type<br/>(dates / mime / checksums / size / format /<br/>duration / camera / exifdate / title /<br/>id3 - audio: Artist/Year - Album / id3-*)<br/>SubPart: --subdirs= or defaults:<br/>image: Form/WxH + EXIF camera/date with --exif<br/>video: WxH/duration - other: size unit/human size]

    DIRS --> NAME[Build_Name: keep / sha / md5 / compressed /<br/>random / size / title / id3-title - id3-track -<br/>folder prefix for files from other directories] --> EXT[Build_Extension:<br/>none / mime / mime-main / mime-sub /<br/>mime-ext / lower / upper /<br/>dynamic keywords (id3-genre ...) / literal]
    EXT --> MKDIR[mkdir -p NewDir]
    MKDIR --> COLL{target exists and<br/>not --replace and non-destructive?}
    COLL -- "yes" --> CNT[append ~(N) collision name] --> SAME
    COLL -- "no" --> SAME{source = target?}
    SAME -- "yes" --> SKIP2[SKIPPED: same place]
    SAME -- "no" --> MODE{mode?}

    MODE -- "Copy" --> CP[cp -v + log + undo + optional --strip] --> DONE[COPIED]
    MODE -- "Move" --> MV[mv -v + log + undo + optional --strip] --> DONE2[MOVED]
    MODE -- "Remove" --> RM[target exists? rm -v + log] --> DONE3[REMOVED]
    MODE -- "Trash" --> TR[target exists? trash-put + log] --> DONE4[TRASHED]
    MODE -- "Shred" --> SH[target exists? shred -u -n 1 + log] --> DONE5[SHREDDED]
    MODE -- "no action mode" --> PV[preview: File <=> New] --> DONE6[PREVIEW]

    DONE & DONE2 & DONE3 & DONE4 & DONE5 & DONE6 & SKIP1 & SKIP2 --> PAUSE{--pause>0?}
    PAUSE -- "yes" --> SLEEP[sleep N] --> NEXT
    PAUSE -- "no" --> NEXT[next file in pool]

    PARCH --> NEXT
    F1 & F2 --> NEXT

    NEXT --> POOL
    POOL -- "all files launched" --> WAIT[wait for all jobs]
    WAIT --> REPORT[report outputs in submission order<br/>count: COPIED MOVED PREVIEW SKIPPED<br/>REMOVED/TRASHED/SHREDDED EXTRACTED FAILED]
    REPORT --> SUMMARY[Summary header + counts<br/>exit 0 only when Failed = 0]
    SUMMARY --> UNDO[--undo: chmod +x the undo script]
    UNDO --> THANKS

    INT([Ctrl-C / SIGINT]) -.->|trap Break INT| WAITJOBS[wait running jobs,<br/>restore IFS, exit 130]
```

## ASCII diagram

```
                        ./Sort.sh  <args>
                              |
                     [ any arguments? ]---no---> Usage --> "Thanks for using HEjder scripts!"
                              | yes
                    Parse_Arguments
          (lang, colored, jobs, modes, dirs/subdirs/rename/
           extension specs, type filter, exif/strip/title,
           audio tags (id3), decompress, log/undo, pause,
           replace, target)
                              |
                    [ Validate_Options ]--no---> error + help hint --> exit 1
                              | yes
                    [ --quiet? ]---no---> Deps_Init (init-system:
                              |           identify ffprobe [+ exiftool]
                              |           [+ tar gzip zip bzip2 xz zstd 7z
                              |            unrar] if --decompress)
                              |<--------- propose install of missing tools
                    Prepare_Optional_Output
                    (open --log=FILE, create --undo script)
                              |
                       Collect_Files
        (find: top-level unless --recursive, prune .* unless
         --hidden, + symlinks with --links  ->  Targets array)
                              |
                    [ Targets empty? ]--yes---> "Nothing to treat" --> exit 1
                              | no
               Draw_Line '=' + header (N files, mode, jobs)
                              |
              +--------------- Run_Threads ---------------+
              |  bounded job pool (Max_Jobs = --jobs=N):  |
              |  while running >= Max_Jobs:  wait -n      |
              |  spawn subshell per file:                 |
              |      Process_File + status tag            |
              |                                           |
              |  Process_File (per file):                 |
              |   regular file? --no--> FAILED            |
              |   MIME type?    --no--> FAILED            |
              |   --type= match? -no--> SKIPPED           |
              |   --decompress + archive?                 |
              |       ---> Process_Archive:               |
              |            test -> mktemp -d -> extract   |
              |            -> sort contents (copy)        |
              |            -> mode on the archive itself  |
              |   DirPart  (--dirs= segments | MIME |     |
              |      id3 tags: Artist/Year - Album)       |
              |   SubPart  (--subdirs= | defaults:        |
              |      image: Form/WxH [+ EXIF cam/date]    |
              |      video: WxH/duration                  |
              |      other: size unit / human size)       |
              |   Build_Name (keep|sha|md5|compressed|    |
              |      random|size|title|id3-*, folder      |
              |      prefix)                              |
              |   Build_Extension (none|mime|mime-main|   |
              |      mime-sub|mime-ext|lower|upper|       |
              |      id3-*|literal)                       |
              |   mkdir -p NewDir                         |
              |   collision? -> append ~(N) (unless       |
              |      --replace / destructive mode)        |
              |   source = target? -> SKIPPED             |
              |   mode dispatch:                          |
              |      Copy  -> cp -v  (+log +undo +strip)  |
              |      Move  -> mv -v  (+log +undo +strip)  |
              |      Remove-> rm -v  (+log)               |
              |      Trash -> trash-put (+log)            |
              |      Shred -> shred -u -n 1 (+log)        |
              |      else  -> PREVIEW  "File <=> New"     |
              |   --pause=N -> sleep N                    |
              +-------------------------------------------+
                              |
                    wait for all jobs
                              |
          report outputs in submission order (tags:
          COPIED MOVED PREVIEW SKIPPED REMOVED/TRASHED/
          SHREDDED EXTRACTED FAILED)
                              |
                    Summary (counts per status)
                    exit 0 only when Failed = 0
                              |
               --undo: chmod +x the undo script
                              |
             "Thanks for using HEjder scripts!"

  trap Break INT: wait running jobs, restore IFS, exit 130
```

---

---

---


# Complete control flow — all 254 functions

Extracted mechanically from `Sort.sh` (V17.3): every function definition and
every call edge between them. **112 functions are reachable from `Main`** — the
actual program; the other **142 form the embedded library** (the "bag of tools":
file, MIME, hash, image, media, EXIF, audio tags, archive helpers) kept complete so they also
work when sourced or called interactively, exactly like the `functions/` modules.
In the graph the library-only nodes are drawn grey/dashed.

## Call tree from Main (the reachable part)

```text
Main
  Usage
    Print_Header
      Print_Line
    T
      Usage  ⤳ (already shown)
    Print_Message
      T  ⤳ (already shown)
  Parse_Arguments
    Color_Enable
      _Color_Set
    Usage  ⤳ (already shown)
    Help
      Print_Header  ⤳ (already shown)
      T  ⤳ (already shown)
      Print_Message  ⤳ (already shown)
      Lang_List
        T  ⤳ (already shown)
        Lang_Name
    Lang_List  ⤳ (already shown)
    Print_Warning
      T  ⤳ (already shown)
    Tf
      T  ⤳ (already shown)
  Validate_Options
    Print_Error
      T  ⤳ (already shown)
    Tf  ⤳ (already shown)
    Lang_List  ⤳ (already shown)
  Deps_Init
    Deps_Has
    Deps_Package
      Deps_Installer
    Tf  ⤳ (already shown)
    _Deps_Propose_Install
      Tf  ⤳ (already shown)
      T  ⤳ (already shown)
      Deps_Install
        Deps_Installer  ⤳ (already shown)
        T  ⤳ (already shown)
        Deps_Priv
    Deps_Missing
      Deps_Has  ⤳ (already shown)
  Prepare_Optional_Output
  Collect_Files
    Print_Warning  ⤳ (already shown)
    Tf  ⤳ (already shown)
    Print_Info
      T  ⤳ (already shown)
  Print_Warning  ⤳ (already shown)
  Draw_Line
  Print_Header  ⤳ (already shown)
  Tf  ⤳ (already shown)
  Run_Threads
    Process_File
      Main  ⤳ (already shown)
      Print_Error  ⤳ (already shown)
      Tf  ⤳ (already shown)
      Get_MIME_Type
      Print_Info  ⤳ (already shown)
      Archive_Is
        Get_Archive_Type
          _Comp_Magic
      Process_Archive
        Print_Error  ⤳ (already shown)
        Tf  ⤳ (already shown)
        Archive_Test
          _Comp_Norm
          Get_Archive_Type  ⤳ (already shown)
          _Comp_Have
            Deps_Ensure
              Deps_Has  ⤳ (already shown)
              Deps_Package  ⤳ (already shown)
              Tf  ⤳ (already shown)
              _Deps_Propose_Install  ⤳ (already shown)
          _Comp_Is_Tar_Suffix
        Archive_Extract
          _Comp_Norm  ⤳ (already shown)
          Get_Archive_Type  ⤳ (already shown)
          _Comp_Have  ⤳ (already shown)
          _Comp_Is_Tar_Suffix  ⤳ (already shown)
        Process_File  ⤳ (already shown)
        Print_Message  ⤳ (already shown)
        Deps_Ensure  ⤳ (already shown)
        Print_Ok
          T  ⤳ (already shown)
        Log_Action
      Build_Segments
        Main  ⤳ (already shown)
        Resolve_Segment
          Main  ⤳ (already shown)
          T  ⤳ (already shown)
          Get_File_Timestamps
          Get_Cached_Date
          Get_Compound_Ext
          Get_File_Ext
          Archive_Main_Name
            Archive_List
              _Comp_Norm  ⤳ (already shown)
              Get_Archive_Type  ⤳ (already shown)
              _Comp_Have  ⤳ (already shown)
              _Comp_Is_Tar_Suffix  ⤳ (already shown)
          Get_File_Name
          Get_MIME_Best_Extension
            Main  ⤳ (already shown)
            Get_MIME_Type  ⤳ (already shown)
            _MIME_Lookup_Ext
            Get_Extension_MIME
          Get_MD5Sum
          Get_SHA1Sum
          Get_SHA224Sum
          Get_SHA256Sum
          Get_SHA384Sum
          Get_SHA512Sum
          Get_B2Sum
          Get_CRC32
          Get_Image_WxH
            Deps_Ensure  ⤳ (already shown)
          Get_Media_WxH
            Deps_Ensure  ⤳ (already shown)
          Get_File_Size_Human
            Get_File_Size
            Human_From_Bytes
              T  ⤳ (already shown)
          Media_Tier
          Media_Orient
          Size_Unit_Name
            Get_File_Size  ⤳ (already shown)
            Size_Unit_From_Bytes
          Video_Duration_Tag
            Get_Duration
              _Probe
                _FF_Have
                  Deps_Ensure  ⤳ (already shown)
                _FF_Run
            Duration_Tag_From_Seconds
          Exif_Camera_Dir
            Get_EXIF_Camera
              _Exif_Has_Reader
              _Exif_Read
                Deps_Ensure  ⤳ (already shown)
            Sanitize_Name
          Exif_Date_Dir
            Get_EXIF_Date
              _Exif_Read  ⤳ (already shown)
          Title_Name
            Main  ⤳ (already shown)
            T  ⤳ (already shown)
            Get_Doc_Title
              Get_File_Name  ⤳ (already shown)
            Exif_Date_Dir  ⤳ (already shown)
            Get_File_Name  ⤳ (already shown)
            Get_Audio_Artist
              T  ⤳ (already shown)
              Id3_Field
                Id3v2_Field
                  Id3v2_Present
                  Id3v2_Major
                    Id3v2_Present  ⤳ (already shown)
                  Id3v2_Tag_Size
                    Id3v2_Present  ⤳ (already shown)
                Id3v1_Field
                  Id3v1_Present
                  Id3v1_Genre_Name
                Id3v1_Genre_Name  ⤳ (already shown)
            Get_Audio_Album
              T  ⤳ (already shown)
              Id3_Field  ⤳ (already shown)
            Get_Audio_Title
              T  ⤳ (already shown)
              Id3_Field  ⤳ (already shown)
            Get_Media_Artist
              _Probe  ⤳ (already shown)
            Get_Media_Title
              _Probe  ⤳ (already shown)
          Get_Audio_Tags_Dir
            Get_Audio_Artist  ⤳ (already shown)
            Get_Audio_Year
              T  ⤳ (already shown)
              Id3_Field  ⤳ (already shown)
            Get_Audio_Album  ⤳ (already shown)
            Sanitize_Name  ⤳ (already shown)
          Sanitize_Name  ⤳ (already shown)
          Id3_Field  ⤳ (already shown)
          Get_File_Base
          Get_Base_Name
            Get_Compound_Ext  ⤳ (already shown)
            Get_File_Name  ⤳ (already shown)
          Get_File_Dir
      Get_Image_WxH  ⤳ (already shown)
      Image_Form
      Exif_Camera_Dir  ⤳ (already shown)
      Exif_Date_Dir  ⤳ (already shown)
      T  ⤳ (already shown)
      Get_Media_Info
        Deps_Ensure  ⤳ (already shown)
        Duration_Tag_From_Seconds  ⤳ (already shown)
      Get_File_Size  ⤳ (already shown)
      Size_Unit_From_Bytes  ⤳ (already shown)
      Human_From_Bytes  ⤳ (already shown)
      Build_Name
        Main  ⤳ (already shown)
        Sanitize_Name  ⤳ (already shown)
        Title_Name  ⤳ (already shown)
        Resolve_Segment  ⤳ (already shown)
        Get_Base_Name  ⤳ (already shown)
      Build_Extension
        Get_Compound_Ext  ⤳ (already shown)
        Get_File_Ext  ⤳ (already shown)
        Resolve_Segment  ⤳ (already shown)
      Print_Ok  ⤳ (already shown)
      Log_Action  ⤳ (already shown)
      Undo_Action
      Strip_Target
        EXIF_Strip
        Print_Info  ⤳ (already shown)
        Tf  ⤳ (already shown)
        Print_Warning  ⤳ (already shown)
      Print_Warning  ⤳ (already shown)
      Deps_Ensure  ⤳ (already shown)
      Print_Message  ⤳ (already shown)
    Print_Header  ⤳ (already shown)
    T  ⤳ (already shown)
    Print_Message  ⤳ (already shown)
    Tf  ⤳ (already shown)
    Print_Ok  ⤳ (already shown)
    Print_Error  ⤳ (already shown)
```

## Full call graph, grouped by module

```mermaid
flowchart TD
    classDef lib fill:#eee,stroke:#999,stroke-dasharray: 5 5
    subgraph M0 ["COLORS"]
        F__Color_Set["_Color_Set"]
        F_Color_Enable["Color_Enable"]
        F_Color_Disable["Color_Disable"] :::lib
        F_Print_Color["Print_Color"] :::lib
        F_Print_Line["Print_Line"]
        F_Print_Header["Print_Header"]
        F_Print_Message["Print_Message"]
        F_Print_Info["Print_Info"]
        F_Print_Ok["Print_Ok"]
        F_Print_Error["Print_Error"]
        F_Print_Warning["Print_Warning"]
        F_Print_Log["Print_Log"] :::lib
        F_Print_Debug["Print_Debug"] :::lib
        F_Color_Preview["Color_Preview"] :::lib
    end
    subgraph M1 ["SYSTEM"]
        F_Exit["Exit"] :::lib
        F_Break["Break"] :::lib
    end
    subgraph M2 ["UI"]
        F_Draw_Line["Draw_Line"]
    end
    subgraph M3 ["DEPS"]
        F_Deps_Has["Deps_Has"]
        F_Deps_Missing["Deps_Missing"]
        F_Deps_Installer["Deps_Installer"]
        F_Deps_Priv["Deps_Priv"]
        F_Deps_Package["Deps_Package"]
        F_Deps_Install["Deps_Install"]
        F__Deps_Propose_Install["_Deps_Propose_Install"]
        F_Deps_Ensure["Deps_Ensure"]
        F_Deps_Init["Deps_Init"]
    end
    subgraph M4 ["FILE"]
        F_Get_MIME["Get_MIME"] :::lib
        F_Get_File_Description["Get_File_Description"] :::lib
        F_Get_File_Encoding["Get_File_Encoding"] :::lib
        F_Get_File_Type["Get_File_Type"] :::lib
        F_Get_File_Name["Get_File_Name"]
        F_Get_File_Base["Get_File_Base"]
        F_Get_File_Ext["Get_File_Ext"]
        F_Get_File_Dir["Get_File_Dir"]
        F_Get_File_Size["Get_File_Size"]
        F_Human_From_Bytes["Human_From_Bytes"]
        F_Get_File_Size_Human["Get_File_Size_Human"]
        F_Get_File_Block_Size["Get_File_Block_Size"] :::lib
        F_Get_File_Line_Count["Get_File_Line_Count"] :::lib
        F_Get_File_Header_Hex["Get_File_Header_Hex"] :::lib
        F_Get_File_Birth["Get_File_Birth"] :::lib
        F_Get_File_Creation_Time["Get_File_Creation_Time"] :::lib
        F_Get_File_Access_Time["Get_File_Access_Time"] :::lib
        F_Get_File_Modification_Time["Get_File_Modification_Time"] :::lib
        F_Get_File_Modified_Epoch["Get_File_Modified_Epoch"] :::lib
        F_Get_File_Accessed_Epoch["Get_File_Accessed_Epoch"] :::lib
        F_Get_File_Changed_Epoch["Get_File_Changed_Epoch"] :::lib
        F_Get_File_Age["Get_File_Age"] :::lib
        F_Get_Date_Part["Get_Date_Part"] :::lib
        F_Get_File_Perm["Get_File_Perm"] :::lib
        F_Get_File_Owner["Get_File_Owner"] :::lib
        F_Get_File_Inode["Get_File_Inode"] :::lib
        F_Get_File_Links["Get_File_Links"] :::lib
        F_Get_Symlink_Target["Get_Symlink_Target"] :::lib
        F_File_Exists["File_Exists"] :::lib
        F_File_Is_Symlink["File_Is_Symlink"] :::lib
        F_File_Is_Hidden["File_Is_Hidden"] :::lib
        F_File_Is_Empty["File_Is_Empty"] :::lib
        F_File_Is_Readable["File_Is_Readable"] :::lib
        F_File_Is_Writable["File_Is_Writable"] :::lib
        F_File_Is_Executable["File_Is_Executable"] :::lib
        F_File_Is_Text["File_Is_Text"] :::lib
        F_File_Is_Binary["File_Is_Binary"] :::lib
    end
    subgraph M5 ["MIME"]
        F_Get_MIME_Main["Get_MIME_Main"] :::lib
        F_Get_MIME_Sub["Get_MIME_Sub"] :::lib
        F_Get_MIME_Type["Get_MIME_Type"]
        F_Get_MIME_Main["Get_MIME_Main"] :::lib
        F_Get_MIME_Sub["Get_MIME_Sub"] :::lib
        F_Get_MIME_Description["Get_MIME_Description"] :::lib
        F_Get_MIME_Charset["Get_MIME_Charset"] :::lib
        F_Get_MIME_All["Get_MIME_All"] :::lib
        F_Get_Magic_Bytes["Get_Magic_Bytes"] :::lib
        F_Get_Magic_String["Get_Magic_String"] :::lib
        F_Get_MIME_By_Magic["Get_MIME_By_Magic"] :::lib
        F__MIME_Lookup_Ext["_MIME_Lookup_Ext"]
        F_Get_MIME_Extension["Get_MIME_Extension"] :::lib
        F_Get_MIME_Best_Extension["Get_MIME_Best_Extension"]
        F_Get_Extension_MIME["Get_Extension_MIME"]
        F_Get_Name_MIME["Get_Name_MIME"] :::lib
        F_MIME_Match["MIME_Match"] :::lib
        F_MIME_Is_Text["MIME_Is_Text"] :::lib
        F_MIME_Is_Binary["MIME_Is_Binary"] :::lib
        F_MIME_Is_Image["MIME_Is_Image"] :::lib
        F_MIME_Is_Video["MIME_Is_Video"] :::lib
        F_MIME_Is_Audio["MIME_Is_Audio"] :::lib
        F_MIME_Is_Archive["MIME_Is_Archive"] :::lib
        F_MIME_Is_Document["MIME_Is_Document"] :::lib
    end
    subgraph M6 ["HASH"]
        F_Get_MD5Sum["Get_MD5Sum"]
        F_Get_SHA1Sum["Get_SHA1Sum"]
        F_Get_SHA224Sum["Get_SHA224Sum"]
        F_Get_SHA256Sum["Get_SHA256Sum"]
        F_Get_SHA384Sum["Get_SHA384Sum"]
        F_Get_SHA512Sum["Get_SHA512Sum"]
        F_Get_B2Sum["Get_B2Sum"]
        F_Get_CRC32["Get_CRC32"]
        F_Get_Hash["Get_Hash"] :::lib
        F_Get_Hash_Of_String["Get_Hash_Of_String"] :::lib
        F_Verify_Hash["Verify_Hash"] :::lib
        F_Files_Are_Identical["Files_Are_Identical"] :::lib
        F_Same_Hash["Same_Hash"] :::lib
        F_Files_Differ["Files_Differ"] :::lib
        F_File_Contains["File_Contains"] :::lib
        F_Find_Copy_In["Find_Copy_In"] :::lib
        F_Dir_Diff["Dir_Diff"] :::lib
        F_Dir_Minus["Dir_Minus"] :::lib
        F_Dir_Minus_Content["Dir_Minus_Content"] :::lib
        F_Dir_Same["Dir_Same"] :::lib
        F_Get_Quick_Hash["Get_Quick_Hash"] :::lib
        F_Find_Duplicates["Find_Duplicates"] :::lib
    end
    subgraph M7 ["IMAGEMAGICK"]
        F__IM_Identify["_IM_Identify"] :::lib
        F__IM_Tool["_IM_Tool"] :::lib
        F_Get_Image_WxH["Get_Image_WxH"]
        F_Get_Image_Width["Get_Image_Width"] :::lib
        F_Get_Image_Height["Get_Image_Height"] :::lib
        F_Get_Image_Format["Get_Image_Format"] :::lib
        F_Get_Image_Colors["Get_Image_Colors"] :::lib
        F_Get_Image_Depth["Get_Image_Depth"] :::lib
        F_Get_Image_Quality["Get_Image_Quality"] :::lib
        F_Get_Image_DPI["Get_Image_DPI"] :::lib
        F_Get_Image_Orientation["Get_Image_Orientation"] :::lib
        F_Get_Image_Camera["Get_Image_Camera"] :::lib
        F_Get_Image_GPS["Get_Image_GPS"] :::lib
        F_Get_Image_Meta["Get_Image_Meta"] :::lib
        F_Image_Is_Valid["Image_Is_Valid"] :::lib
        F_Get_WxH_Format["Get_WxH_Format"] :::lib
        F_Image_Resize["Image_Resize"] :::lib
        F_Image_Thumbnail["Image_Thumbnail"] :::lib
        F_Image_Convert["Image_Convert"] :::lib
        F_Image_Rotate["Image_Rotate"] :::lib
        F_Image_Grayscale["Image_Grayscale"] :::lib
        F_Image_Strip["Image_Strip"] :::lib
    end
    subgraph M8 ["FFMPEG"]
        F__FF_Have["_FF_Have"]
        F__FF_Run["_FF_Run"]
        F__Probe["_Probe"]
        F__Probe_Stream["_Probe_Stream"] :::lib
        F_Get_Media_WxH["Get_Media_WxH"]
        F_Get_Media_Info["Get_Media_Info"]
        F_Get_Video_Codec["Get_Video_Codec"] :::lib
        F_Get_Audio_Codec["Get_Audio_Codec"] :::lib
        F_Get_Container["Get_Container"] :::lib
        F_Get_Duration["Get_Duration"]
        F_Get_Duration_Human["Get_Duration_Human"] :::lib
        F_Get_Bitrate["Get_Bitrate"] :::lib
        F_Get_FPS["Get_FPS"] :::lib
        F_Get_Audio_Channels["Get_Audio_Channels"] :::lib
        F_Get_Sample_Rate["Get_Sample_Rate"] :::lib
        F_Get_Media_Title["Get_Media_Title"]
        F_Get_Media_Artist["Get_Media_Artist"]
        F_Get_Media_Album["Get_Media_Album"] :::lib
        F_Get_Media_Genre["Get_Media_Genre"] :::lib
        F_Get_Media_Track["Get_Media_Track"] :::lib
        F_Get_Media_Date["Get_Media_Date"] :::lib
        F_Get_Media_Tags["Get_Media_Tags"] :::lib
        F_Media_Is_Valid["Media_Is_Valid"] :::lib
        F_Get_Audio_Info["Get_Audio_Info"] :::lib
        F_Get_Video_Title["Get_Video_Title"] :::lib
        F_Media_Extract_Audio["Media_Extract_Audio"] :::lib
        F_Media_Convert["Media_Convert"] :::lib
        F_Media_Thumbnail["Media_Thumbnail"] :::lib
        F_Media_Strip_Metadata["Media_Strip_Metadata"] :::lib
    end
    subgraph M9 ["EXIF"]
        F__Exif_Read["_Exif_Read"]
        F__Exif_Has_Reader["_Exif_Has_Reader"]
        F__Exif_Have["_Exif_Have"] :::lib
        F_Get_EXIF["Get_EXIF"] :::lib
        F_Get_EXIF_All["Get_EXIF_All"] :::lib
        F_Get_EXIF_Tags["Get_EXIF_Tags"] :::lib
        F_EXIF_Is_Present["EXIF_Is_Present"] :::lib
        F_Get_EXIF_Date["Get_EXIF_Date"]
        F_Get_EXIF_CreateDate["Get_EXIF_CreateDate"] :::lib
        F_Get_EXIF_Camera["Get_EXIF_Camera"]
        F_Get_EXIF_Lens["Get_EXIF_Lens"] :::lib
        F_Get_EXIF_ISO["Get_EXIF_ISO"] :::lib
        F_Get_EXIF_Exposure["Get_EXIF_Exposure"] :::lib
        F_Get_EXIF_Aperture["Get_EXIF_Aperture"] :::lib
        F_Get_EXIF_FocalLength["Get_EXIF_FocalLength"] :::lib
        F_Get_EXIF_Flash["Get_EXIF_Flash"] :::lib
        F_Get_EXIF_Orientation["Get_EXIF_Orientation"] :::lib
        F_Get_EXIF_GPS_Lat["Get_EXIF_GPS_Lat"] :::lib
        F_Get_EXIF_GPS_Lon["Get_EXIF_GPS_Lon"] :::lib
        F_Get_EXIF_GPS["Get_EXIF_GPS"] :::lib
        F_Get_EXIF_GPS_Alt["Get_EXIF_GPS_Alt"] :::lib
        F_Get_EXIF_Artist["Get_EXIF_Artist"] :::lib
        F_Get_EXIF_Copyright["Get_EXIF_Copyright"] :::lib
        F_EXIF_Strip["EXIF_Strip"]
        F_EXIF_Set["EXIF_Set"] :::lib
        F_EXIF_Copy["EXIF_Copy"] :::lib
    end
    subgraph M10 ["TAGS"]
        F_Id3v1_Present["Id3v1_Present"]
        F_Id3v1_Genre_Name["Id3v1_Genre_Name"]
        F_Id3v1_Field["Id3v1_Field"]
        F_Id3v2_Present["Id3v2_Present"]
        F_Id3v2_Major["Id3v2_Major"]
        F_Id3v2_Tag_Size["Id3v2_Tag_Size"]
        F_Id3v2_Field["Id3v2_Field"]
        F_Id3_Field["Id3_Field"]
        F_Get_Audio_Title["Get_Audio_Title"]
        F_Get_Audio_Artist["Get_Audio_Artist"]
        F_Get_Audio_Album["Get_Audio_Album"]
        F_Get_Audio_Year["Get_Audio_Year"]
        F_Get_Audio_Genre["Get_Audio_Genre"] :::lib
        F_Get_Audio_Track["Get_Audio_Track"] :::lib
        F_Get_Audio_Tags_Dir["Get_Audio_Tags_Dir"]
    end
    subgraph M11 ["COMPRESSION"]
        F__Comp_Have["_Comp_Have"]
        F__Comp_Norm["_Comp_Norm"]
        F__Comp_Is_Tar_Suffix["_Comp_Is_Tar_Suffix"]
        F__Comp_Magic["_Comp_Magic"]
        F_Get_Archive_Type["Get_Archive_Type"]
        F_Archive_Is["Archive_Is"]
        F_Archive_Test["Archive_Test"]
        F_Archive_List["Archive_List"]
        F_Archive_Extract["Archive_Extract"]
        F_Archive_Main_Name["Archive_Main_Name"]
        F_Compress_File["Compress_File"] :::lib
        F_Compress_Gzip["Compress_Gzip"] :::lib
        F_Compress_Bzip2["Compress_Bzip2"] :::lib
        F_Compress_Xz["Compress_Xz"] :::lib
        F_Compress_Zstd["Compress_Zstd"] :::lib
        F_Archive_Create["Archive_Create"] :::lib
    end
    subgraph M12 ["DOCS"]
        F_Get_Doc_Title["Get_Doc_Title"]
    end
    subgraph M13 ["DRIVER - defaults, parsing, the dynamic-value engine and the thread pool"]
        F_T["T"]
        F_Tf["Tf"]
        F_Lang_Name["Lang_Name"]
        F_Lang_List["Lang_List"]
        F_Usage["Usage"]
        F_Help["Help"]
        F_Parse_Arguments["Parse_Arguments"]
        F_Validate_Options["Validate_Options"]
        F_Collect_Files["Collect_Files"]
        F_Sanitize_Name["Sanitize_Name"]
        F_Media_Tier["Media_Tier"]
        F_Media_Orient["Media_Orient"]
        F_Size_Unit_From_Bytes["Size_Unit_From_Bytes"]
        F_Size_Unit_Name["Size_Unit_Name"]
        F_Exif_Date_Dir["Exif_Date_Dir"]
        F_Exif_Camera_Dir["Exif_Camera_Dir"]
        F_Title_Name["Title_Name"]
        F_Get_File_Timestamps["Get_File_Timestamps"]
        F_Get_Cached_Date["Get_Cached_Date"]
        F_Resolve_Segment["Resolve_Segment"]
        F_Build_Segments["Build_Segments"]
        F_Build_Name["Build_Name"]
        F_Get_Base_Name["Get_Base_Name"]
        F_Get_Compound_Ext["Get_Compound_Ext"]
        F_Build_Extension["Build_Extension"]
        F_Prepare_Optional_Output["Prepare_Optional_Output"]
        F_Log_Action["Log_Action"]
        F_Undo_Action["Undo_Action"]
        F_Strip_Target["Strip_Target"]
        F_Image_Form["Image_Form"]
        F_Duration_Tag_From_Seconds["Duration_Tag_From_Seconds"]
        F_Video_Duration_Tag["Video_Duration_Tag"]
        F_Process_Archive["Process_Archive"]
        F_Process_File["Process_File"]
        F_Run_Threads["Run_Threads"]
        F_Main["Main"]
    end
    F_Color_Enable --> F__Color_Set
    F_Color_Disable --> F__Color_Set
    F_Print_Header --> F_Print_Line
    F_Print_Message --> F_T
    F_Print_Info --> F_T
    F_Print_Ok --> F_T
    F_Print_Error --> F_T
    F_Print_Warning --> F_T
    F_Color_Preview --> F_Print_Color
    F_Exit --> F_T
    F_Break --> F_T
    F_Break --> F_Exit
    F_Deps_Missing --> F_Deps_Has
    F_Deps_Package --> F_Deps_Installer
    F_Deps_Install --> F_Deps_Installer
    F_Deps_Install --> F_T
    F_Deps_Install --> F_Deps_Priv
    F__Deps_Propose_Install --> F_Tf
    F__Deps_Propose_Install --> F_T
    F__Deps_Propose_Install --> F_Deps_Install
    F_Deps_Ensure --> F_Deps_Has
    F_Deps_Ensure --> F_Deps_Package
    F_Deps_Ensure --> F_Tf
    F_Deps_Ensure --> F__Deps_Propose_Install
    F_Deps_Init --> F_Deps_Has
    F_Deps_Init --> F_Deps_Package
    F_Deps_Init --> F_Tf
    F_Deps_Init --> F__Deps_Propose_Install
    F_Deps_Init --> F_Deps_Missing
    F_Get_MIME_Main --> F_Get_MIME_Type
    F_Get_MIME_Sub --> F_Get_MIME_Type
    F_Human_From_Bytes --> F_T
    F_Get_File_Size_Human --> F_Get_File_Size
    F_Get_File_Size_Human --> F_Human_From_Bytes
    F_Get_File_Age --> F_Get_File_Modified_Epoch
    F_Get_Date_Part --> F_Get_File_Birth
    F_File_Is_Text --> F_Get_File_Encoding
    F_File_Is_Binary --> F_Get_File_Encoding
    F_Get_MIME_Main --> F_Get_MIME_Type
    F_Get_MIME_Sub --> F_Get_MIME_Type
    F_Get_MIME_All --> F_Get_MIME_Type
    F_Get_MIME_All --> F_Get_MIME_Description
    F_Get_MIME_All --> F_Get_MIME_Charset
    F_Get_MIME_All --> F_Get_MIME_Extension
    F_Get_MIME_All --> F_Get_Magic_Bytes
    F_Get_MIME_All --> F_Main
    F_Get_MIME_By_Magic --> F_Get_Magic_Bytes
    F_Get_MIME_Extension --> F_Get_MIME_Type
    F_Get_MIME_Extension --> F__MIME_Lookup_Ext
    F_Get_MIME_Best_Extension --> F_Main
    F_Get_MIME_Best_Extension --> F_Get_MIME_Type
    F_Get_MIME_Best_Extension --> F__MIME_Lookup_Ext
    F_Get_MIME_Best_Extension --> F_Get_Extension_MIME
    F_Get_Name_MIME --> F_Get_Extension_MIME
    F_MIME_Match --> F_Get_MIME_Type
    F_MIME_Is_Text --> F_Get_MIME_Type
    F_MIME_Is_Binary --> F_Get_MIME_Charset
    F_MIME_Is_Image --> F_Get_MIME_Main
    F_MIME_Is_Video --> F_Get_MIME_Main
    F_MIME_Is_Audio --> F_Get_MIME_Main
    F_MIME_Is_Archive --> F_Get_MIME_Type
    F_MIME_Is_Document --> F_Get_MIME_Type
    F_Get_Hash --> F_Get_MD5Sum
    F_Get_Hash --> F_Get_SHA1Sum
    F_Get_Hash --> F_Get_SHA224Sum
    F_Get_Hash --> F_Get_SHA256Sum
    F_Get_Hash --> F_Get_SHA384Sum
    F_Get_Hash --> F_Get_SHA512Sum
    F_Get_Hash --> F_Get_B2Sum
    F_Get_Hash --> F_Get_CRC32
    F_Verify_Hash --> F_Get_Hash
    F_Same_Hash --> F_Get_Hash
    F_Find_Copy_In --> F_Get_Hash
    F_Dir_Diff --> F_Get_Hash
    F_Dir_Minus_Content --> F_Get_Hash
    F_Dir_Same --> F_Dir_Diff
    F_Find_Duplicates --> F_Get_Hash
    F__IM_Identify --> F_Deps_Ensure
    F__IM_Tool --> F_Deps_Ensure
    F_Get_Image_WxH --> F_Deps_Ensure
    F_Get_Image_Width --> F__IM_Identify
    F_Get_Image_Height --> F__IM_Identify
    F_Get_Image_Format --> F__IM_Identify
    F_Get_Image_Colors --> F__IM_Identify
    F_Get_Image_Depth --> F__IM_Identify
    F_Get_Image_Quality --> F__IM_Identify
    F_Get_Image_DPI --> F__IM_Identify
    F_Get_Image_Orientation --> F__IM_Identify
    F_Get_Image_Camera --> F__IM_Identify
    F_Get_Image_GPS --> F__IM_Identify
    F_Get_Image_Meta --> F__IM_Identify
    F_Image_Is_Valid --> F__IM_Identify
    F_Image_Resize --> F__IM_Tool
    F_Image_Thumbnail --> F__IM_Tool
    F_Image_Convert --> F__IM_Tool
    F_Image_Rotate --> F__IM_Tool
    F_Image_Grayscale --> F__IM_Tool
    F_Image_Strip --> F__IM_Tool
    F__FF_Have --> F_Deps_Ensure
    F__Probe --> F__FF_Have
    F__Probe --> F__FF_Run
    F__Probe_Stream --> F__FF_Have
    F__Probe_Stream --> F__FF_Run
    F_Get_Media_WxH --> F_Deps_Ensure
    F_Get_Media_Info --> F_Deps_Ensure
    F_Get_Media_Info --> F_Duration_Tag_From_Seconds
    F_Get_Video_Codec --> F__Probe_Stream
    F_Get_Audio_Codec --> F__Probe_Stream
    F_Get_Container --> F__Probe
    F_Get_Duration --> F__Probe
    F_Get_Duration_Human --> F__Probe
    F_Get_Bitrate --> F__Probe
    F_Get_FPS --> F__Probe_Stream
    F_Get_Audio_Channels --> F__Probe_Stream
    F_Get_Sample_Rate --> F__Probe_Stream
    F_Get_Media_Title --> F__Probe
    F_Get_Media_Artist --> F__Probe
    F_Get_Media_Album --> F__Probe
    F_Get_Media_Genre --> F__Probe
    F_Get_Media_Track --> F__Probe
    F_Get_Media_Date --> F__Probe
    F_Get_Media_Tags --> F__FF_Have
    F_Media_Is_Valid --> F__FF_Have
    F_Get_Audio_Info --> F__FF_Have
    F_Get_Video_Title --> F__FF_Have
    F_Media_Extract_Audio --> F__FF_Have
    F_Media_Convert --> F__FF_Have
    F_Media_Thumbnail --> F__FF_Have
    F_Media_Strip_Metadata --> F__FF_Have
    F__Exif_Read --> F_Deps_Ensure
    F__Exif_Have --> F_Deps_Ensure
    F_Get_EXIF --> F__Exif_Read
    F_Get_EXIF_All --> F__Exif_Have
    F_Get_EXIF_Tags --> F_Get_EXIF_All
    F_EXIF_Is_Present --> F_Get_EXIF_All
    F_Get_EXIF_Date --> F__Exif_Read
    F_Get_EXIF_CreateDate --> F__Exif_Read
    F_Get_EXIF_Camera --> F__Exif_Has_Reader
    F_Get_EXIF_Camera --> F__Exif_Read
    F_Get_EXIF_Lens --> F__Exif_Has_Reader
    F_Get_EXIF_Lens --> F__Exif_Read
    F_Get_EXIF_ISO --> F__Exif_Read
    F_Get_EXIF_Exposure --> F__Exif_Read
    F_Get_EXIF_Aperture --> F__Exif_Read
    F_Get_EXIF_FocalLength --> F__Exif_Read
    F_Get_EXIF_Flash --> F__Exif_Read
    F_Get_EXIF_Orientation --> F__Exif_Read
    F_Get_EXIF_GPS_Lat --> F__Exif_Read
    F_Get_EXIF_GPS_Lon --> F__Exif_Read
    F_Get_EXIF_GPS --> F__Exif_Has_Reader
    F_Get_EXIF_GPS --> F_Get_EXIF_GPS_Lat
    F_Get_EXIF_GPS --> F_Get_EXIF_GPS_Lon
    F_Get_EXIF_GPS_Alt --> F__Exif_Read
    F_Get_EXIF_Artist --> F__Exif_Read
    F_Get_EXIF_Copyright --> F__Exif_Read
    F_EXIF_Set --> F__Exif_Have
    F_EXIF_Copy --> F__Exif_Have
    F_Id3v1_Field --> F_Id3v1_Present
    F_Id3v1_Field --> F_Id3v1_Genre_Name
    F_Id3v2_Major --> F_Id3v2_Present
    F_Id3v2_Tag_Size --> F_Id3v2_Present
    F_Id3v2_Field --> F_Id3v2_Present
    F_Id3v2_Field --> F_Id3v2_Major
    F_Id3v2_Field --> F_Id3v2_Tag_Size
    F_Id3_Field --> F_Id3v2_Field
    F_Id3_Field --> F_Id3v1_Field
    F_Id3_Field --> F_Id3v1_Genre_Name
    F_Get_Audio_Title --> F_T
    F_Get_Audio_Title --> F_Id3_Field
    F_Get_Audio_Artist --> F_T
    F_Get_Audio_Artist --> F_Id3_Field
    F_Get_Audio_Album --> F_T
    F_Get_Audio_Album --> F_Id3_Field
    F_Get_Audio_Year --> F_T
    F_Get_Audio_Year --> F_Id3_Field
    F_Get_Audio_Genre --> F_T
    F_Get_Audio_Genre --> F_Id3_Field
    F_Get_Audio_Track --> F_T
    F_Get_Audio_Track --> F_Id3_Field
    F_Get_Audio_Tags_Dir --> F_Get_Audio_Artist
    F_Get_Audio_Tags_Dir --> F_Get_Audio_Year
    F_Get_Audio_Tags_Dir --> F_Get_Audio_Album
    F_Get_Audio_Tags_Dir --> F_Sanitize_Name
    F__Comp_Have --> F_Deps_Ensure
    F_Get_Archive_Type --> F__Comp_Magic
    F_Archive_Is --> F_Get_Archive_Type
    F_Archive_Test --> F__Comp_Norm
    F_Archive_Test --> F_Get_Archive_Type
    F_Archive_Test --> F__Comp_Have
    F_Archive_Test --> F__Comp_Is_Tar_Suffix
    F_Archive_List --> F__Comp_Norm
    F_Archive_List --> F_Get_Archive_Type
    F_Archive_List --> F__Comp_Have
    F_Archive_List --> F__Comp_Is_Tar_Suffix
    F_Archive_Extract --> F__Comp_Norm
    F_Archive_Extract --> F_Get_Archive_Type
    F_Archive_Extract --> F__Comp_Have
    F_Archive_Extract --> F__Comp_Is_Tar_Suffix
    F_Archive_Main_Name --> F_Archive_List
    F_Compress_File --> F__Comp_Have
    F_Compress_Gzip --> F_Compress_File
    F_Compress_Bzip2 --> F_Compress_File
    F_Compress_Xz --> F_Compress_File
    F_Compress_Zstd --> F_Compress_File
    F_Archive_Create --> F__Comp_Norm
    F_Archive_Create --> F__Comp_Have
    F_Get_Doc_Title --> F_Get_File_Name
    F_T --> F_Usage
    F_Tf --> F_T
    F_Lang_List --> F_T
    F_Lang_List --> F_Lang_Name
    F_Usage --> F_Print_Header
    F_Usage --> F_T
    F_Usage --> F_Print_Message
    F_Help --> F_Print_Header
    F_Help --> F_T
    F_Help --> F_Print_Message
    F_Help --> F_Lang_List
    F_Parse_Arguments --> F_Color_Enable
    F_Parse_Arguments --> F_Usage
    F_Parse_Arguments --> F_Help
    F_Parse_Arguments --> F_Lang_List
    F_Parse_Arguments --> F_Print_Warning
    F_Parse_Arguments --> F_Tf
    F_Validate_Options --> F_Print_Error
    F_Validate_Options --> F_Tf
    F_Validate_Options --> F_Lang_List
    F_Collect_Files --> F_Print_Warning
    F_Collect_Files --> F_Tf
    F_Collect_Files --> F_Print_Info
    F_Size_Unit_Name --> F_Get_File_Size
    F_Size_Unit_Name --> F_Size_Unit_From_Bytes
    F_Exif_Date_Dir --> F_Get_EXIF_Date
    F_Exif_Camera_Dir --> F_Get_EXIF_Camera
    F_Exif_Camera_Dir --> F_Sanitize_Name
    F_Title_Name --> F_Main
    F_Title_Name --> F_T
    F_Title_Name --> F_Get_Doc_Title
    F_Title_Name --> F_Exif_Date_Dir
    F_Title_Name --> F_Get_File_Name
    F_Title_Name --> F_Get_Audio_Artist
    F_Title_Name --> F_Get_Audio_Album
    F_Title_Name --> F_Get_Audio_Title
    F_Title_Name --> F_Get_Media_Artist
    F_Title_Name --> F_Get_Media_Title
    F_Resolve_Segment --> F_Main
    F_Resolve_Segment --> F_T
    F_Resolve_Segment --> F_Get_File_Timestamps
    F_Resolve_Segment --> F_Get_Cached_Date
    F_Resolve_Segment --> F_Get_Compound_Ext
    F_Resolve_Segment --> F_Get_File_Ext
    F_Resolve_Segment --> F_Archive_Main_Name
    F_Resolve_Segment --> F_Get_File_Name
    F_Resolve_Segment --> F_Get_MIME_Best_Extension
    F_Resolve_Segment --> F_Get_MD5Sum
    F_Resolve_Segment --> F_Get_SHA1Sum
    F_Resolve_Segment --> F_Get_SHA224Sum
    F_Resolve_Segment --> F_Get_SHA256Sum
    F_Resolve_Segment --> F_Get_SHA384Sum
    F_Resolve_Segment --> F_Get_SHA512Sum
    F_Resolve_Segment --> F_Get_B2Sum
    F_Resolve_Segment --> F_Get_CRC32
    F_Resolve_Segment --> F_Get_Image_WxH
    F_Resolve_Segment --> F_Get_Media_WxH
    F_Resolve_Segment --> F_Get_File_Size_Human
    F_Resolve_Segment --> F_Media_Tier
    F_Resolve_Segment --> F_Media_Orient
    F_Resolve_Segment --> F_Size_Unit_Name
    F_Resolve_Segment --> F_Video_Duration_Tag
    F_Resolve_Segment --> F_Exif_Camera_Dir
    F_Resolve_Segment --> F_Exif_Date_Dir
    F_Resolve_Segment --> F_Title_Name
    F_Resolve_Segment --> F_Get_Audio_Tags_Dir
    F_Resolve_Segment --> F_Sanitize_Name
    F_Resolve_Segment --> F_Id3_Field
    F_Resolve_Segment --> F_Get_File_Base
    F_Resolve_Segment --> F_Get_Base_Name
    F_Resolve_Segment --> F_Get_File_Dir
    F_Build_Segments --> F_Main
    F_Build_Segments --> F_Resolve_Segment
    F_Build_Name --> F_Main
    F_Build_Name --> F_Sanitize_Name
    F_Build_Name --> F_Title_Name
    F_Build_Name --> F_Resolve_Segment
    F_Build_Name --> F_Get_Base_Name
    F_Get_Base_Name --> F_Get_Compound_Ext
    F_Get_Base_Name --> F_Get_File_Name
    F_Build_Extension --> F_Get_Compound_Ext
    F_Build_Extension --> F_Get_File_Ext
    F_Build_Extension --> F_Resolve_Segment
    F_Strip_Target --> F_EXIF_Strip
    F_Strip_Target --> F_Print_Info
    F_Strip_Target --> F_Tf
    F_Strip_Target --> F_Print_Warning
    F_Video_Duration_Tag --> F_Get_Duration
    F_Video_Duration_Tag --> F_Duration_Tag_From_Seconds
    F_Process_Archive --> F_Print_Error
    F_Process_Archive --> F_Tf
    F_Process_Archive --> F_Archive_Test
    F_Process_Archive --> F_Archive_Extract
    F_Process_Archive --> F_Process_File
    F_Process_Archive --> F_Print_Message
    F_Process_Archive --> F_Deps_Ensure
    F_Process_Archive --> F_Print_Ok
    F_Process_Archive --> F_Log_Action
    F_Process_File --> F_Main
    F_Process_File --> F_Print_Error
    F_Process_File --> F_Tf
    F_Process_File --> F_Get_MIME_Type
    F_Process_File --> F_Print_Info
    F_Process_File --> F_Archive_Is
    F_Process_File --> F_Process_Archive
    F_Process_File --> F_Build_Segments
    F_Process_File --> F_Get_Image_WxH
    F_Process_File --> F_Image_Form
    F_Process_File --> F_Exif_Camera_Dir
    F_Process_File --> F_Exif_Date_Dir
    F_Process_File --> F_T
    F_Process_File --> F_Get_Media_Info
    F_Process_File --> F_Get_File_Size
    F_Process_File --> F_Size_Unit_From_Bytes
    F_Process_File --> F_Human_From_Bytes
    F_Process_File --> F_Build_Name
    F_Process_File --> F_Build_Extension
    F_Process_File --> F_Print_Ok
    F_Process_File --> F_Log_Action
    F_Process_File --> F_Undo_Action
    F_Process_File --> F_Strip_Target
    F_Process_File --> F_Print_Warning
    F_Process_File --> F_Deps_Ensure
    F_Process_File --> F_Print_Message
    F_Run_Threads --> F_Process_File
    F_Run_Threads --> F_Print_Header
    F_Run_Threads --> F_T
    F_Run_Threads --> F_Print_Message
    F_Run_Threads --> F_Tf
    F_Run_Threads --> F_Print_Ok
    F_Run_Threads --> F_Print_Error
    F_Main --> F_Usage
    F_Main --> F_Parse_Arguments
    F_Main --> F_Validate_Options
    F_Main --> F_Deps_Init
    F_Main --> F_Prepare_Optional_Output
    F_Main --> F_Collect_Files
    F_Main --> F_Print_Warning
    F_Main --> F_Draw_Line
    F_Main --> F_Print_Header
    F_Main --> F_Tf
    F_Main --> F_Run_Threads
```

## Full call table

Every function with the functions it calls (first-use order).

### COLORS

- **_Color_Set** — (leaf)
- **Color_Enable**: `_Color_Set`
- **Color_Disable** *(library — not on the Main path)*: `_Color_Set`
- **Print_Color** *(library — not on the Main path)* — (leaf)
- **Print_Line** — (leaf)
- **Print_Header**: `Print_Line`
- **Print_Message**: `T`
- **Print_Info**: `T`
- **Print_Ok**: `T`
- **Print_Error**: `T`
- **Print_Warning**: `T`
- **Print_Log** *(library — not on the Main path)* — (leaf)
- **Print_Debug** *(library — not on the Main path)* — (leaf)
- **Color_Preview** *(library — not on the Main path)*: `Print_Color`

### SYSTEM

- **Exit** *(library — not on the Main path)*: `T`
- **Break** *(library — not on the Main path)*: `T`, `Exit`

### UI

- **Draw_Line** — (leaf)

### DEPS

- **Deps_Has** — (leaf)
- **Deps_Missing**: `Deps_Has`
- **Deps_Installer** — (leaf)
- **Deps_Priv** — (leaf)
- **Deps_Package**: `Deps_Installer`
- **Deps_Install**: `Deps_Installer`, `T`, `Deps_Priv`
- **_Deps_Propose_Install**: `Tf`, `T`, `Deps_Install`
- **Deps_Ensure**: `Deps_Has`, `Deps_Package`, `Tf`, `_Deps_Propose_Install`
- **Deps_Init**: `Deps_Has`, `Deps_Package`, `Tf`, `_Deps_Propose_Install`, `Deps_Missing`

### FILE

- **Get_MIME** *(library — not on the Main path)* — (leaf)
- **Get_File_Description** *(library — not on the Main path)* — (leaf)
- **Get_File_Encoding** *(library — not on the Main path)* — (leaf)
- **Get_File_Type** *(library — not on the Main path)* — (leaf)
- **Get_File_Name** — (leaf)
- **Get_File_Base** — (leaf)
- **Get_File_Ext** — (leaf)
- **Get_File_Dir** — (leaf)
- **Get_File_Size** — (leaf)
- **Human_From_Bytes**: `T`
- **Get_File_Size_Human**: `Get_File_Size`, `Human_From_Bytes`
- **Get_File_Block_Size** *(library — not on the Main path)* — (leaf)
- **Get_File_Line_Count** *(library — not on the Main path)* — (leaf)
- **Get_File_Header_Hex** *(library — not on the Main path)* — (leaf)
- **Get_File_Birth** *(library — not on the Main path)* — (leaf)
- **Get_File_Creation_Time** *(library — not on the Main path)* — (leaf)
- **Get_File_Access_Time** *(library — not on the Main path)* — (leaf)
- **Get_File_Modification_Time** *(library — not on the Main path)* — (leaf)
- **Get_File_Modified_Epoch** *(library — not on the Main path)* — (leaf)
- **Get_File_Accessed_Epoch** *(library — not on the Main path)* — (leaf)
- **Get_File_Changed_Epoch** *(library — not on the Main path)* — (leaf)
- **Get_File_Age** *(library — not on the Main path)*: `Get_File_Modified_Epoch`
- **Get_Date_Part** *(library — not on the Main path)*: `Get_File_Birth`
- **Get_File_Perm** *(library — not on the Main path)* — (leaf)
- **Get_File_Owner** *(library — not on the Main path)* — (leaf)
- **Get_File_Inode** *(library — not on the Main path)* — (leaf)
- **Get_File_Links** *(library — not on the Main path)* — (leaf)
- **Get_Symlink_Target** *(library — not on the Main path)* — (leaf)
- **File_Exists** *(library — not on the Main path)* — (leaf)
- **File_Is_Symlink** *(library — not on the Main path)* — (leaf)
- **File_Is_Hidden** *(library — not on the Main path)* — (leaf)
- **File_Is_Empty** *(library — not on the Main path)* — (leaf)
- **File_Is_Readable** *(library — not on the Main path)* — (leaf)
- **File_Is_Writable** *(library — not on the Main path)* — (leaf)
- **File_Is_Executable** *(library — not on the Main path)* — (leaf)
- **File_Is_Text** *(library — not on the Main path)*: `Get_File_Encoding`
- **File_Is_Binary** *(library — not on the Main path)*: `Get_File_Encoding`

### MIME

- **Get_MIME_Main** *(library — not on the Main path)*: `Get_MIME_Type`
- **Get_MIME_Sub** *(library — not on the Main path)*: `Get_MIME_Type`
- **Get_MIME_Type** — (leaf)
- **Get_MIME_Main** *(library — not on the Main path)*: `Get_MIME_Type`
- **Get_MIME_Sub** *(library — not on the Main path)*: `Get_MIME_Type`
- **Get_MIME_Description** *(library — not on the Main path)* — (leaf)
- **Get_MIME_Charset** *(library — not on the Main path)* — (leaf)
- **Get_MIME_All** *(library — not on the Main path)*: `Get_MIME_Type`, `Get_MIME_Description`, `Get_MIME_Charset`, `Get_MIME_Extension`, `Get_Magic_Bytes`, `Main`
- **Get_Magic_Bytes** *(library — not on the Main path)* — (leaf)
- **Get_Magic_String** *(library — not on the Main path)* — (leaf)
- **Get_MIME_By_Magic** *(library — not on the Main path)*: `Get_Magic_Bytes`
- **_MIME_Lookup_Ext** — (leaf)
- **Get_MIME_Extension** *(library — not on the Main path)*: `Get_MIME_Type`, `_MIME_Lookup_Ext`
- **Get_MIME_Best_Extension**: `Main`, `Get_MIME_Type`, `_MIME_Lookup_Ext`, `Get_Extension_MIME`
- **Get_Extension_MIME** — (leaf)
- **Get_Name_MIME** *(library — not on the Main path)*: `Get_Extension_MIME`
- **MIME_Match** *(library — not on the Main path)*: `Get_MIME_Type`
- **MIME_Is_Text** *(library — not on the Main path)*: `Get_MIME_Type`
- **MIME_Is_Binary** *(library — not on the Main path)*: `Get_MIME_Charset`
- **MIME_Is_Image** *(library — not on the Main path)*: `Get_MIME_Main`
- **MIME_Is_Video** *(library — not on the Main path)*: `Get_MIME_Main`
- **MIME_Is_Audio** *(library — not on the Main path)*: `Get_MIME_Main`
- **MIME_Is_Archive** *(library — not on the Main path)*: `Get_MIME_Type`
- **MIME_Is_Document** *(library — not on the Main path)*: `Get_MIME_Type`

### HASH

- **Get_MD5Sum** — (leaf)
- **Get_SHA1Sum** — (leaf)
- **Get_SHA224Sum** — (leaf)
- **Get_SHA256Sum** — (leaf)
- **Get_SHA384Sum** — (leaf)
- **Get_SHA512Sum** — (leaf)
- **Get_B2Sum** — (leaf)
- **Get_CRC32** — (leaf)
- **Get_Hash** *(library — not on the Main path)*: `Get_MD5Sum`, `Get_SHA1Sum`, `Get_SHA224Sum`, `Get_SHA256Sum`, `Get_SHA384Sum`, `Get_SHA512Sum`, `Get_B2Sum`, `Get_CRC32`
- **Get_Hash_Of_String** *(library — not on the Main path)* — (leaf)
- **Verify_Hash** *(library — not on the Main path)*: `Get_Hash`
- **Files_Are_Identical** *(library — not on the Main path)* — (leaf)
- **Same_Hash** *(library — not on the Main path)*: `Get_Hash`
- **Files_Differ** *(library — not on the Main path)* — (leaf)
- **File_Contains** *(library — not on the Main path)* — (leaf)
- **Find_Copy_In** *(library — not on the Main path)*: `Get_Hash`
- **Dir_Diff** *(library — not on the Main path)*: `Get_Hash`
- **Dir_Minus** *(library — not on the Main path)* — (leaf)
- **Dir_Minus_Content** *(library — not on the Main path)*: `Get_Hash`
- **Dir_Same** *(library — not on the Main path)*: `Dir_Diff`
- **Get_Quick_Hash** *(library — not on the Main path)* — (leaf)
- **Find_Duplicates** *(library — not on the Main path)*: `Get_Hash`

### IMAGEMAGICK

- **_IM_Identify** *(library — not on the Main path)*: `Deps_Ensure`
- **_IM_Tool** *(library — not on the Main path)*: `Deps_Ensure`
- **Get_Image_WxH**: `Deps_Ensure`
- **Get_Image_Width** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Height** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Format** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Colors** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Depth** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Quality** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_DPI** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Orientation** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Camera** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_GPS** *(library — not on the Main path)*: `_IM_Identify`
- **Get_Image_Meta** *(library — not on the Main path)*: `_IM_Identify`
- **Image_Is_Valid** *(library — not on the Main path)*: `_IM_Identify`
- **Get_WxH_Format** *(library — not on the Main path)* — (leaf)
- **Image_Resize** *(library — not on the Main path)*: `_IM_Tool`
- **Image_Thumbnail** *(library — not on the Main path)*: `_IM_Tool`
- **Image_Convert** *(library — not on the Main path)*: `_IM_Tool`
- **Image_Rotate** *(library — not on the Main path)*: `_IM_Tool`
- **Image_Grayscale** *(library — not on the Main path)*: `_IM_Tool`
- **Image_Strip** *(library — not on the Main path)*: `_IM_Tool`

### FFMPEG

- **_FF_Have**: `Deps_Ensure`
- **_FF_Run** — (leaf)
- **_Probe**: `_FF_Have`, `_FF_Run`
- **_Probe_Stream** *(library — not on the Main path)*: `_FF_Have`, `_FF_Run`
- **Get_Media_WxH**: `Deps_Ensure`
- **Get_Media_Info**: `Deps_Ensure`, `Duration_Tag_From_Seconds`
- **Get_Video_Codec** *(library — not on the Main path)*: `_Probe_Stream`
- **Get_Audio_Codec** *(library — not on the Main path)*: `_Probe_Stream`
- **Get_Container** *(library — not on the Main path)*: `_Probe`
- **Get_Duration**: `_Probe`
- **Get_Duration_Human** *(library — not on the Main path)*: `_Probe`
- **Get_Bitrate** *(library — not on the Main path)*: `_Probe`
- **Get_FPS** *(library — not on the Main path)*: `_Probe_Stream`
- **Get_Audio_Channels** *(library — not on the Main path)*: `_Probe_Stream`
- **Get_Sample_Rate** *(library — not on the Main path)*: `_Probe_Stream`
- **Get_Media_Title**: `_Probe`
- **Get_Media_Artist**: `_Probe`
- **Get_Media_Album** *(library — not on the Main path)*: `_Probe`
- **Get_Media_Genre** *(library — not on the Main path)*: `_Probe`
- **Get_Media_Track** *(library — not on the Main path)*: `_Probe`
- **Get_Media_Date** *(library — not on the Main path)*: `_Probe`
- **Get_Media_Tags** *(library — not on the Main path)*: `_FF_Have`
- **Media_Is_Valid** *(library — not on the Main path)*: `_FF_Have`
- **Get_Audio_Info** *(library — not on the Main path)*: `_FF_Have`
- **Get_Video_Title** *(library — not on the Main path)*: `_FF_Have`
- **Media_Extract_Audio** *(library — not on the Main path)*: `_FF_Have`
- **Media_Convert** *(library — not on the Main path)*: `_FF_Have`
- **Media_Thumbnail** *(library — not on the Main path)*: `_FF_Have`
- **Media_Strip_Metadata** *(library — not on the Main path)*: `_FF_Have`

### EXIF

- **_Exif_Read**: `Deps_Ensure`
- **_Exif_Has_Reader** — (leaf)
- **_Exif_Have** *(library — not on the Main path)*: `Deps_Ensure`
- **Get_EXIF** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_All** *(library — not on the Main path)*: `_Exif_Have`
- **Get_EXIF_Tags** *(library — not on the Main path)*: `Get_EXIF_All`
- **EXIF_Is_Present** *(library — not on the Main path)*: `Get_EXIF_All`
- **Get_EXIF_Date**: `_Exif_Read`
- **Get_EXIF_CreateDate** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Camera**: `_Exif_Has_Reader`, `_Exif_Read`
- **Get_EXIF_Lens** *(library — not on the Main path)*: `_Exif_Has_Reader`, `_Exif_Read`
- **Get_EXIF_ISO** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Exposure** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Aperture** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_FocalLength** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Flash** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Orientation** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_GPS_Lat** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_GPS_Lon** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_GPS** *(library — not on the Main path)*: `_Exif_Has_Reader`, `Get_EXIF_GPS_Lat`, `Get_EXIF_GPS_Lon`
- **Get_EXIF_GPS_Alt** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Artist** *(library — not on the Main path)*: `_Exif_Read`
- **Get_EXIF_Copyright** *(library — not on the Main path)*: `_Exif_Read`
- **EXIF_Strip** — (leaf)
- **EXIF_Set** *(library — not on the Main path)*: `_Exif_Have`
- **EXIF_Copy** *(library — not on the Main path)*: `_Exif_Have`

### TAGS

- **Id3v1_Present** — (leaf)
- **Id3v1_Genre_Name** — (leaf)
- **Id3v1_Field**: `Id3v1_Present`, `Id3v1_Genre_Name`
- **Id3v2_Present** — (leaf)
- **Id3v2_Major**: `Id3v2_Present`
- **Id3v2_Tag_Size**: `Id3v2_Present`
- **Id3v2_Field**: `Id3v2_Present`, `Id3v2_Major`, `Id3v2_Tag_Size`
- **Id3_Field**: `Id3v2_Field`, `Id3v1_Field`, `Id3v1_Genre_Name`
- **Get_Audio_Title**: `T`, `Id3_Field`
- **Get_Audio_Artist**: `T`, `Id3_Field`
- **Get_Audio_Album**: `T`, `Id3_Field`
- **Get_Audio_Year**: `T`, `Id3_Field`
- **Get_Audio_Genre** *(library — not on the Main path)*: `T`, `Id3_Field`
- **Get_Audio_Track** *(library — not on the Main path)*: `T`, `Id3_Field`
- **Get_Audio_Tags_Dir**: `Get_Audio_Artist`, `Get_Audio_Year`, `Get_Audio_Album`, `Sanitize_Name`

### COMPRESSION

- **_Comp_Have**: `Deps_Ensure`
- **_Comp_Norm** — (leaf)
- **_Comp_Is_Tar_Suffix** — (leaf)
- **_Comp_Magic** — (leaf)
- **Get_Archive_Type**: `_Comp_Magic`
- **Archive_Is**: `Get_Archive_Type`
- **Archive_Test**: `_Comp_Norm`, `Get_Archive_Type`, `_Comp_Have`, `_Comp_Is_Tar_Suffix`
- **Archive_List**: `_Comp_Norm`, `Get_Archive_Type`, `_Comp_Have`, `_Comp_Is_Tar_Suffix`
- **Archive_Extract**: `_Comp_Norm`, `Get_Archive_Type`, `_Comp_Have`, `_Comp_Is_Tar_Suffix`
- **Archive_Main_Name**: `Archive_List`
- **Compress_File** *(library — not on the Main path)*: `_Comp_Have`
- **Compress_Gzip** *(library — not on the Main path)*: `Compress_File`
- **Compress_Bzip2** *(library — not on the Main path)*: `Compress_File`
- **Compress_Xz** *(library — not on the Main path)*: `Compress_File`
- **Compress_Zstd** *(library — not on the Main path)*: `Compress_File`
- **Archive_Create** *(library — not on the Main path)*: `_Comp_Norm`, `_Comp_Have`

### DOCS

- **Get_Doc_Title**: `Get_File_Name`

### DRIVER - defaults, parsing, the dynamic-value engine and the thread pool

- **T**: `Usage`
- **Tf**: `T`
- **Lang_Name** — (leaf)
- **Lang_List**: `T`, `Lang_Name`
- **Usage**: `Print_Header`, `T`, `Print_Message`
- **Help**: `Print_Header`, `T`, `Print_Message`, `Lang_List`
- **Parse_Arguments**: `Color_Enable`, `Usage`, `Help`, `Lang_List`, `Print_Warning`, `Tf`
- **Validate_Options**: `Print_Error`, `Tf`, `Lang_List`
- **Collect_Files**: `Print_Warning`, `Tf`, `Print_Info`
- **Sanitize_Name** — (leaf)
- **Media_Tier** — (leaf)
- **Media_Orient** — (leaf)
- **Size_Unit_From_Bytes** — (leaf)
- **Size_Unit_Name**: `Get_File_Size`, `Size_Unit_From_Bytes`
- **Exif_Date_Dir**: `Get_EXIF_Date`
- **Exif_Camera_Dir**: `Get_EXIF_Camera`, `Sanitize_Name`
- **Title_Name**: `Main`, `T`, `Get_Doc_Title`, `Exif_Date_Dir`, `Get_File_Name`, `Get_Audio_Artist`, `Get_Audio_Album`, `Get_Audio_Title`, `Get_Media_Artist`, `Get_Media_Title`
- **Get_File_Timestamps** — (leaf)
- **Get_Cached_Date** — (leaf)
- **Resolve_Segment**: `Main`, `T`, `Get_File_Timestamps`, `Get_Cached_Date`, `Get_Compound_Ext`, `Get_File_Ext`, `Archive_Main_Name`, `Get_File_Name`, `Get_MIME_Best_Extension`, `Get_MD5Sum`, `Get_SHA1Sum`, `Get_SHA224Sum`, `Get_SHA256Sum`, `Get_SHA384Sum`, `Get_SHA512Sum`, `Get_B2Sum`, `Get_CRC32`, `Get_Image_WxH`, `Get_Media_WxH`, `Get_File_Size_Human`, `Media_Tier`, `Media_Orient`, `Size_Unit_Name`, `Video_Duration_Tag`, `Exif_Camera_Dir`, `Exif_Date_Dir`, `Title_Name`, `Get_Audio_Tags_Dir`, `Sanitize_Name`, `Id3_Field`, `Get_File_Base`, `Get_Base_Name`, `Get_File_Dir`
- **Build_Segments**: `Main`, `Resolve_Segment`
- **Build_Name**: `Main`, `Sanitize_Name`, `Title_Name`, `Resolve_Segment`, `Get_Base_Name`
- **Get_Base_Name**: `Get_Compound_Ext`, `Get_File_Name`
- **Get_Compound_Ext** — (leaf)
- **Build_Extension**: `Get_Compound_Ext`, `Get_File_Ext`, `Resolve_Segment`
- **Prepare_Optional_Output** — (leaf)
- **Log_Action** — (leaf)
- **Undo_Action** — (leaf)
- **Strip_Target**: `EXIF_Strip`, `Print_Info`, `Tf`, `Print_Warning`
- **Image_Form** — (leaf)
- **Duration_Tag_From_Seconds** — (leaf)
- **Video_Duration_Tag**: `Get_Duration`, `Duration_Tag_From_Seconds`
- **Process_Archive**: `Print_Error`, `Tf`, `Archive_Test`, `Archive_Extract`, `Process_File`, `Print_Message`, `Deps_Ensure`, `Print_Ok`, `Log_Action`
- **Process_File**: `Main`, `Print_Error`, `Tf`, `Get_MIME_Type`, `Print_Info`, `Archive_Is`, `Process_Archive`, `Build_Segments`, `Get_Image_WxH`, `Image_Form`, `Exif_Camera_Dir`, `Exif_Date_Dir`, `T`, `Get_Media_Info`, `Get_File_Size`, `Size_Unit_From_Bytes`, `Human_From_Bytes`, `Build_Name`, `Build_Extension`, `Print_Ok`, `Log_Action`, `Undo_Action`, `Strip_Target`, `Print_Warning`, `Deps_Ensure`, `Print_Message`
- **Run_Threads**: `Process_File`, `Print_Header`, `T`, `Print_Message`, `Tf`, `Print_Ok`, `Print_Error`
- **Main**: `Usage`, `Parse_Arguments`, `Validate_Options`, `Deps_Init`, `Prepare_Optional_Output`, `Collect_Files`, `Print_Warning`, `Draw_Line`, `Print_Header`, `Tf`, `Run_Threads`
