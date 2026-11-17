# Sort.sh V17.1 — program flow diagram

The actual control flow of the main `Sort.sh` (V17.1), traced from the code:
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
    ARCH -- "no" --> DIRS[DirPart: --dirs= segments or MIME type<br/>SubPart: --subdirs= or defaults:<br/>image: Form/WxH + EXIF camera/date with --exif<br/>video: WxH/duration - other: size unit/human size]

    DIRS --> NAME[Build_Name: keep / sha / md5 / compressed /<br/>random / size / title - folder prefix for files<br/>from other directories] --> EXT[Build_Extension:<br/>none / mime / mime-main / mime-sub /<br/>mime-ext / literal]
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
           decompress, log/undo, pause, replace, target)
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
              |   DirPart  (--dirs= segments | MIME)      |
              |   SubPart  (--subdirs= | defaults:        |
              |      image: Form/WxH [+ EXIF cam/date]    |
              |      video: WxH/duration                  |
              |      other: size unit / human size)       |
              |   Build_Name (keep|sha|md5|compressed|    |
              |      random|size|title, folder prefix)    |
              |   Build_Extension (none|mime|mime-main|   |
              |      mime-sub|mime-ext|literal)           |
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
