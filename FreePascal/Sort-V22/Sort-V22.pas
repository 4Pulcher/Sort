{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{                                                                             }
{  Script  : Sort-V22.pas                                                         }
{  Version : 22                                                             }
{  Desc    : Ejder file organizer - FreePascal translation of Sort.sh v22   }
{  Author  : HEjder                                                           }
{                                                                             }
{  Translated to FreePascal 3.2.2 (target: FPC 3.2.2, mode objfpc, H+).       }
{  Compile with:  fpc -Mobjfpc -Sh Sort.pas                                   }
{                                                                             }
{  Native FreePascal libraries used:                                          }
{    - SysUtils, Classes, Math  : RTL / FCL                                   }
{    - MD5, SHA1                : packages/hash (native hashing)              }
{    - Zipper                   : FCL (native zip read/extract)               }
{    - SyncObjs                 : FCL (thread pool locking)                   }
{    - BaseUnix                 : RTL (stat / symlink / chmod)                }
{    - Process (TProcess)       : FCL (external tools, the same ones the      }
{      shell version called: file, exiftool, ffprobe, identify, trash-put,    }
{      shred, tar, gzip, bzip2, xz, zstd, 7z, unrar, sha256sum, sha512sum)    }
{                                                                             }
{  NOTE: FPC has no native SHA256/SHA512 unit (packages/hash only ships       }
{  md5 and sha1), so those two fall back to the same external tools the       }
{  shell version used.                                                        }
{                                                                             }
{*****************************************************************************}
{$MODE OBJFPC}{$H+}
program Sort;

uses
    SysUtils, Classes, Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix,
    Process, StrUtils;

const
    ScriptVersion = '22';
    ClosingPhrase = 'Thanks for using HEjder scripts!';

    C_Reset  = #27 + '[0m';
    C_Red    = #27 + '[31m';
    C_Green  = #27 + '[32m';
    C_Yellow = #27 + '[33m';
    C_Blue   = #27 + '[34m';
    C_Bold   = #27 + '[1m';

type
    TSortThread = class(TThread)
    protected
        procedure Execute; override;
    end;

var
    { Options }
    Modus          : string;   { print / copy / move / remove / trash / shred }
    DirList        : string;   { --dirs=LEVEL[,LEVEL...] }
    SubList        : string;   { --subdirs=LEVEL[,LEVEL...] }
    RenameVal      : string;   { --rename=VALUE }
    ExtensionVal   : string;   { --extension=VALUE }
    TypeFilter     : string;   { --type=VALUE }
    SourceDir      : string;   { --source=DIR }
    TargetDir      : string;   { --target=DIR }
    PauseSec       : Integer;  { --pause=SEC }
    LogFile        : string;   { --log=FILE }
    UndoFile       : string;   { --undo[=FILE] }
    JobCount       : Integer;  { --jobs=N }
    { Flags }
    DoReplace      : Boolean;
    DoRecursive    : Boolean;
    DoHidden       : Boolean;
    DoLinks        : Boolean;
    DoColored      : Boolean;
    DoQuiet        : Boolean;
    DoVerbose      : Boolean;
    DoStats        : Boolean;
    DoStrip        : Boolean;
    DoExif         : Boolean;
    DoDecompress   : Boolean;
    DoSelfTest     : Boolean;
    Magic_Mode     : Boolean;      { V17.5: --magic detection report }

    { State }
    Files          : TStringList;
    NextIdx        : Integer;
    Lock           : TCriticalSection;
    DecompressDepth: Integer;
    CountCopied    : Integer;
    CountMoved     : Integer;
    CountRemoved   : Integer;
    CountTrashed   : Integer;
    CountShredded  : Integer;
    CountSkipped   : Integer;
    CountFailed    : Integer;
    CountExtracted : Integer;
    CountPreview   : Integer;
    UndoLines      : TStringList;

{ ------------------------------------------------------------------ }
{ Output helpers (thread-safe)                                        }
{ ------------------------------------------------------------------ }

{ Out_Tagged: print a tagged line (thread-safe) }
procedure Out_Tagged(const Tag, S: string);
begin
    Lock.Enter;
    try
        if DoColored then
            WriteLn(C_Bold + Tag + C_Reset + ' ' + S)
        else
            WriteLn(Tag + ' ' + S);
    finally
        Lock.Leave;
    end;
end;

{ Out_Err: print an error line to stderr }
procedure Out_Err(const S: string);
begin
    Lock.Enter;
    try
        if DoColored then
            WriteLn(StdErr, C_Red + S + C_Reset)
        else
            WriteLn(StdErr, S);
    finally
        Lock.Leave;
    end;
end;

{ Out_Log: verbose line + append to the log file }
procedure Out_Log(const S: string);
begin
    if DoVerbose then
        Out_Tagged('#', S);
    if LogFile <> '' then
    begin
        Lock.Enter;
        try
            with TStringList.Create do
            try
                if FileExists(LogFile) then
                    LoadFromFile(LogFile);
                Add(S);
                SaveToFile(LogFile);
            finally
                Free;
            end;
        finally
            Lock.Leave;
        end;
    end;
end;

{ Bump: thread-safe counter increment }
procedure Bump(var C: Integer);
begin
    Lock.Enter;
    try
        C := C + 1;
    finally
        Lock.Leave;
    end;
end;

{ ------------------------------------------------------------------ }
{ External tool helpers (same tools the shell version called)         }
{ ------------------------------------------------------------------ }

{ HaveTool: true when an external tool exists on PATH }
function HaveTool(const Exe: string): Boolean;
begin
    if Pos(PathSep, Exe) > 0 then
        Result := FileExists(Exe)
    else
        Result := FileSearch(Exe, GetEnvironmentVariable('PATH')) <> '';
end;

{ Run Exe with Args, capture merged stdout+stderr, return exit code.
  127 = tool missing (same convention as the shell library). }
function RunTool(const Exe: string; const Args: array of string; out Text: string): Integer;
var
    P   : TProcess;
    Buf : string;
    N   : LongInt;
    I   : Integer;
begin
    Text := '';
    if not HaveTool(Exe) then
        Exit(127);
    P := TProcess.Create(nil);
    try
        P.Executable := Exe;
        P.Options := P.Options + [poUsePipes, poStderrToOutPut];
        for I := Low(Args) to High(Args) do
            P.Parameters.Add(Args[I]);
        P.Execute;
        SetLength(Buf, 4096);
        while P.Running do
        begin
            N := P.Output.Read(Buf[1], 4096);
            if N > 0 then
                Text := Text + Copy(Buf, 1, N)
            else
                Sleep(10);
        end;
        repeat
            N := P.Output.Read(Buf[1], 4096);
            if N > 0 then
                Text := Text + Copy(Buf, 1, N);
        until N <= 0;
        Result := P.ExitStatus;
    finally
        P.Free;
    end;
end;

{ ------------------------------------------------------------------ }
{ File helpers                                                        }
{ ------------------------------------------------------------------ }

{ Is_Symlink: true when the path is a symbolic link }
function Is_Symlink(const F: string): Boolean;
var
    SB: TStat;
begin
    Result := False;
    if FpLStat(F, SB) = 0 then
        Result := FPS_ISLNK(SB.st_mode);
end;

{ Get_File_Size: file size in bytes (stat) }
function Get_File_Size(const F: string): Int64;
var
    SB: TStat;
begin
    Result := 0;
    if FpStat(F, SB) = 0 then
        Result := SB.st_size;
end;

{ Copy_File: copy a file byte by byte (TFileStream) }
function Copy_File(const Src, Dst: string): Boolean;
var
    InS, OutS: TFileStream;
begin
    Result := False;
    InS := nil;
    OutS := nil;
    try
        try
            InS := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
            OutS := TFileStream.Create(Dst, fmCreate);
            OutS.CopyFrom(InS, InS.Size);
            Result := True;
        except
            Result := False;
        end;
    finally
        OutS.Free;
        InS.Free;
    end;
end;

{ Move_File: move a file: rename, or copy+delete across devices }
function Move_File(const Src, Dst: string): Boolean;
begin
    if RenameFile(Src, Dst) then
        Result := True
    else
    begin
        Result := Copy_File(Src, Dst);
        if Result then
            DeleteFile(Src);
    end;
end;

{ Shred_File: overwrite a file with random bytes, then delete it }
procedure Shred_File(const F: string);
var
    FS   : TFileStream;
    Buf  : array[1..4096] of Byte;
    Left : Int64;
    I    : Integer;
    Dummy: string;
begin
    if HaveTool('shred') then
    begin
        RunTool('shred', ['-u', '-n', '1', F], Dummy);
        Exit;
    end;
    { Manual fallback: overwrite once with random bytes, then delete }
    try
        FS := TFileStream.Create(F, fmOpenReadWrite);
        try
            Left := FS.Size;
            while Left > 0 do
            begin
                for I := 1 to SizeOf(Buf) do
                    Buf[I] := Random(256);
                if Left < SizeOf(Buf) then
                    FS.Write(Buf, Left)
                else
                    FS.Write(Buf, SizeOf(Buf));
                Dec(Left, Min(SizeOf(Buf), Left));
            end;
        finally
            FS.Free;
        end;
    except
        { unreadable file: fall through to plain delete }
    end;
    DeleteFile(F);
end;

{ Trash_File: move a file to the trash (trash-put / trash) }
function Trash_File(const F: string; out Text: string): Integer;
begin
    if HaveTool('trash-put') then
        Result := RunTool('trash-put', [F], Text)
    else if HaveTool('trash') then
        Result := RunTool('trash', [F], Text)
    else
        Result := 127;
end;

{ Last-dot extension, without the dot }
function Get_File_Ext(const F: string): string;
var
    Base: string;
    Dot: Integer;
begin
    Base := ExtractFileName(F);
    Dot := LastDelimiter('.', Base);
    if (Dot > 1) and (Dot < Length(Base)) then
        Result := Copy(Base, Dot + 1, MaxInt)
    else
        Result := '';
end;

{ Name without ANY extension (last-dot variant) }
function Name_Without_Ext(const F: string): string;
var
    Base: string;
    Dot: Integer;
begin
    Base := ExtractFileName(F);
    Dot := LastDelimiter('.', Base);
    if Dot > 1 then
        Result := Copy(Base, 1, Dot - 1)
    else
        Result := Base;
end;

{ Dotted suffixes like .tar.gz / .TAR.GZ count as ONE extension.
  Returns True and Suffix without the leading dot, e.g. 'tar.gz'. }
function Get_Compound_Ext(const F: string; out Suffix: string): Boolean;
const
    Comps: array[1..11] of string = (
        '.tar.gz', '.tgz', '.tar.bz2', '.tbz2', '.tbz', '.tar.xz', '.txz',
        '.tar.zst', '.tzst', '.tar.lzma', '.tar.lz');
var
    Base, LBase: string;
    I: Integer;
begin
    Result := False;
    Suffix := '';
    Base := ExtractFileName(F);
    LBase := LowerCase(Base);
    for I := Low(Comps) to High(Comps) do
        if Length(Low) > Length(Comps[I]) then
            if Copy(LBase, Length(LBase) - Length(Comps[I]) + 1, Length(Comps[I])) = Comps[I] then
            begin
                Suffix := Copy(Base, Length(Base) - Length(Comps[I]) + 2, MaxInt);
                Result := True;
                Exit;
            end;
end;

{ Name without ANY extension - a compound suffix counts as one }
function Get_Base_Name(const F: string): string;
var
    Suffix: string;
begin
    if Get_Compound_Ext(F, Suffix) then
        Result := Copy(ExtractFileName(F), 1,
                       Length(ExtractFileName(F)) - Length(Suffix) - 1)
    else
        Result := Name_Without_Ext(F);
end;

{ ------------------------------------------------------------------ }
{ MIME helpers (file(1), same as the shell library)                   }
{ ------------------------------------------------------------------ }

{ Detect_MIME: MIME type of a file via file(1) }
function Detect_MIME(const F: string): string;
var
    Res: string;
begin
    Result := '';
    if RunTool('file', ['-b', '--mime-type', F], Res) = 0 then
    begin
        Res := Trim(Res);
        if Pos(';', Res) > 0 then
            Res := Trim(Copy(Res, 1, Pos(';', Res) - 1));
        Result := LowerCase(Res);
    end;
end;

{ MIME_Main: main part of a MIME type (before the /) }
function MIME_Main(const M: string): string;
var
    P: Integer;
begin
    P := Pos('/', M);
    if P > 0 then
        Result := Copy(M, 1, P - 1)
    else
        Result := M;
end;

{ MIME_Sub: sub part of a MIME type (after the /) }
function MIME_Sub(const M: string): string;
var
    P: Integer;
begin
    P := Pos('/', M);
    if P > 0 then
        Result := Copy(M, P + 1, MaxInt)
    else
        Result := '';
end;

{ Best matching extension for a MIME type (compact subset of the shell's
  687-entry table; the matching chain is the same as shell mime v2.2:
  exact hit, own extension when it maps back to the type, main-type
  default for extensionless files, original extension as last resort). }
function MIME_Table(const M: string): string;
begin
    if M = 'text/plain' then Result := 'txt'
    else if M = 'text/x-shellscript' then Result := 'sh'
    else if M = 'text/html' then Result := 'html'
    else if M = 'text/csv' then Result := 'csv'
    else if M = 'text/markdown' then Result := 'md'
    else if M = 'application/pdf' then Result := 'pdf'
    else if M = 'application/zip' then Result := 'zip'
    else if M = 'application/gzip' then Result := 'gz'
    else if M = 'application/x-gzip' then Result := 'gz'
    else if M = 'application/x-bzip2' then Result := 'bz2'
    else if M = 'application/x-xz' then Result := 'xz'
    else if M = 'application/zstd' then Result := 'zst'
    else if M = 'application/x-7z-compressed' then Result := '7z'
    else if M = 'application/x-rar' then Result := 'rar'
    else if M = 'application/x-rar-compressed' then Result := 'rar'
    else if M = 'application/x-tar' then Result := 'tar'
    else if M = 'application/json' then Result := 'json'
    else if M = 'application/xml' then Result := 'xml'
    else if M = 'application/x-yaml' then Result := 'yaml'
    else if M = 'image/jpeg' then Result := 'jpg'
    else if M = 'image/png' then Result := 'png'
    else if M = 'image/gif' then Result := 'gif'
    else if M = 'image/webp' then Result := 'webp'
    else if M = 'image/svg+xml' then Result := 'svg'
    else if M = 'image/tiff' then Result := 'tif'
    else if M = 'image/bmp' then Result := 'bmp'
    else if M = 'image/x-icon' then Result := 'ico'
    else if M = 'audio/mpeg' then Result := 'mp3'
    else if M = 'audio/ogg' then Result := 'ogg'
    else if M = 'audio/wav' then Result := 'wav'
    else if M = 'audio/x-wav' then Result := 'wav'
    else if M = 'audio/flac' then Result := 'flac'
    else if M = 'audio/mp4' then Result := 'm4a'
    else if M = 'video/mp4' then Result := 'mp4'
    else if M = 'video/mpeg' then Result := 'mpeg'
    else if M = 'video/webm' then Result := 'webm'
    else if M = 'video/x-matroska' then Result := 'mkv'
    else if M = 'video/quicktime' then Result := 'mov'
    else if M = 'video/x-msvideo' then Result := 'avi'
    else if M = 'application/octet-stream' then Result := 'bin'
    else if M = 'application/x-executable' then Result := 'bin'
    else if M = 'application/x-sharedlib' then Result := 'so'
    else if M = 'application/x-object' then Result := 'o'
    else if M = 'application/sql' then Result := 'sql'
    else if M = 'application/x-sqlite3' then Result := 'sqlite'
    else if M = 'application/epub+zip' then Result := 'epub'
    else if M = 'application/vnd.debian.binary-package' then Result := 'deb'
    else if M = 'application/x-rpm' then Result := 'rpm'
    else if M = 'application/msword' then Result := 'doc'
    else if M = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' then Result := 'docx'
    else if M = 'application/vnd.ms-excel' then Result := 'xls'
    else if M = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' then Result := 'xlsx'
    else if M = 'application/vnd.ms-powerpoint' then Result := 'ppt'
    else if M = 'application/vnd.openxmlformats-officedocument.presentationml.presentation' then Result := 'pptx'
    else if M = 'application/font-woff' then Result := 'woff'
    else if M = 'application/x-font-ttf' then Result := 'ttf'
    else if M = 'application/x-font-otf' then Result := 'otf'
    else
        Result := '';
end;

{ extension -> MIME, used to accept a file's own extension when it maps
  back to the detected type (same rule as the shell mime v2.2 chain) }
function Ext_To_MIME(const E: string): string;
begin
    if E = 'txt' then Result := 'text/plain'
    else if E = 'sh' then Result := 'text/x-shellscript'
    else if E = 'html' then Result := 'text/html'
    else if E = 'csv' then Result := 'text/csv'
    else if E = 'md' then Result := 'text/markdown'
    else if E = 'pdf' then Result := 'application/pdf'
    else if E = 'zip' then Result := 'application/zip'
    else if E = 'gz' then Result := 'application/gzip'
    else if E = 'bz2' then Result := 'application/x-bzip2'
    else if E = 'xz' then Result := 'application/x-xz'
    else if E = 'zst' then Result := 'application/zstd'
    else if E = '7z' then Result := 'application/x-7z-compressed'
    else if E = 'rar' then Result := 'application/x-rar'
    else if E = 'tar' then Result := 'application/x-tar'
    else if E = 'jpg' then Result := 'image/jpeg'
    else if E = 'jpeg' then Result := 'image/jpeg'
    else if E = 'png' then Result := 'image/png'
    else if E = 'gif' then Result := 'image/gif'
    else if E = 'webp' then Result := 'image/webp'
    else if E = 'svg' then Result := 'image/svg+xml'
    else if E = 'mp3' then Result := 'audio/mpeg'
    else if E = 'ogg' then Result := 'audio/ogg'
    else if E = 'wav' then Result := 'audio/x-wav'
    else if E = 'flac' then Result := 'audio/flac'
    else if E = 'mp4' then Result := 'video/mp4'
    else if E = 'mkv' then Result := 'video/x-matroska'
    else if E = 'webm' then Result := 'video/webm'
    else if E = 'mov' then Result := 'video/quicktime'
    else if E = 'avi' then Result := 'video/x-msvideo'
    else if E = 'json' then Result := 'application/json'
    else if E = 'xml' then Result := 'application/xml'
    else
        Result := '';
end;

{ Get_MIME_Best_Extension: best matching extension for the MIME type of a file }
function Get_MIME_Best_Extension(const F: string): string;
var
    Mime, OwnExt, Base: string;
    Dot: Integer;
begin
    Result := '';
    Mime := Detect_MIME(F);
    if Mime = '' then
        Exit;
    { 1: exact table hit }
    Result := MIME_Table(Mime);
    if Result <> '' then
        Exit;
    Base := ExtractFileName(F);
    Dot := LastDelimiter('.', Base);
    { 2: keep the file's own extension when it maps back to the type }
    if Dot > 1 then
    begin
        OwnExt := LowerCase(Copy(Base, Dot + 1, MaxInt));
        if Ext_To_MIME(OwnExt) = Mime then
        begin
            Result := OwnExt;
            Exit;
        end;
    end;
    { 3: main-type default for extensionless files }
    if Dot <= 1 then
    begin
        if MIME_Main(Mime) = 'text' then Result := 'txt'
        else if MIME_Main(Mime) = 'image' then Result := 'img'
        else if MIME_Main(Mime) = 'audio' then Result := 'mp3'
        else if MIME_Main(Mime) = 'video' then Result := 'mp4'
        else if MIME_Main(Mime) = 'application' then Result := 'bin';
    end;
    { 4: original extension as last resort }
    if (Result = '') and (Dot > 1) then
        Result := LowerCase(Copy(Base, Dot + 1, MaxInt));
end;

{ ------------------------------------------------------------------ }
{ Hashing (native MD5/SHA1, external sha256sum/sha512sum)             }
{ ------------------------------------------------------------------ }

{ First_Token: first space-separated token of a string }
function First_Token(const S: string): string;
var
    P: Integer;
begin
    P := Pos(' ', S);
    if P > 0 then
        Result := Copy(S, 1, P - 1)
    else
        Result := S;
end;

{ Hash_File: hash a file with the given algorithm (md5/sha1 native, sha256/sha512 external) }
function Hash_File(const F, Algo: string): string;
var
    Res: string;
begin
    Result := '';
    if Algo = 'md5' then
        Result := MD5Print(MD5File(F))
    else if Algo = 'sha1' then
        Result := SHA1Print(SHA1File(F))
    else if Algo = 'sha256' then
    begin
        if RunTool('sha256sum', [F], Res) = 0 then
            Result := First_Token(Trim(Res));
    end
    else if Algo = 'sha512' then
    begin
        if RunTool('sha512sum', [F], Res) = 0 then
            Result := First_Token(Trim(Res));
    end;
end;

{ ------------------------------------------------------------------ }
{ Archives (native Zipper for zip, external tools for the rest)       }
{ ------------------------------------------------------------------ }

{ Is_Zip_File: true when the file starts with the PK zip magic }
function Is_Zip_File(const F: string): Boolean;
var
    FS: TFileStream;
    Sig: array[1..4] of Byte;
    N: Integer;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    try
        FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
        try
            if FS.Size < 4 then
                Exit;
            N := FS.Read(Sig, 4);
            Result := (N = 4) and (Sig[1] = $50) and (Sig[2] = $4B)
                      and ((Sig[3] = $03) or (Sig[3] = $05) or (Sig[3] = $07));
        finally
            FS.Free;
        end;
    except
        Result := False;
    end;
end;

{ Is_Tar_Suffix: true for .tar / .tar.gz / .tar.bz2 / ... names }
function Is_Tar_Suffix(const F: string): Boolean;
var
    S: string;
begin
    Result := Get_Compound_Ext(F, S);
    if Result then
    begin
        S := LowerCase(S);
        Result := (Pos('tar', S) > 0)
                  or (S = 'tgz') or (S = 'tbz2') or (S = 'tbz')
                  or (S = 'txz') or (S = 'tzst');
    end;
end;

{ last component of a compound suffix, e.g. .tar.gz -> gz }
function Get_Compound_Ext_Last(const F: string): string;
var
    S: string;
begin
    if Get_Compound_Ext(F, S) then
    begin
        S := LowerCase(S);
        if Pos('.', S) > 0 then
            Result := Copy(S, LastDelimiter('.', S) + 1, MaxInt)
        else
            Result := S;
    end
    else
        Result := LowerCase(Get_File_Ext(F));
end;

{ Main directory inside an archive, or base name of a single file.
  Returns '' when it cannot be determined. }
function Archive_Main_Name(const F: string): string;
var
    U: TUnZipper;
    I, K: Integer;
    Entry, Top, Res, Common: string;
begin
    Result := '';
    if Is_Zip_File(F) then
    begin
        U := TUnZipper.Create;
        try
            U.FileName := F;
            U.Examine;
            if U.Entries.Count = 1 then
            begin
                Entry := U.Entries[0].ArchiveFileName;
                Result := ChangeFileExt(ExtractFileName(Entry), '');
                Exit;
            end;
            Common := '';
            for I := 0 to U.Entries.Count - 1 do
            begin
                Entry := U.Entries[I].ArchiveFileName;
                K := Pos('/', Entry);
                if K = 0 then
                    Exit;  { loose files: ambiguous }
                Top := Copy(Entry, 1, K - 1);
                if Common = '' then
                    Common := Top
                else if Common <> Top then
                    Exit;  { several top-level dirs: ambiguous }
            end;
            Result := Common;
        finally
            U.Free;
        end;
        Exit;
    end;
    if HaveTool('tar') then
    begin
        if RunTool('tar', ['-tf', F], Res) <> 0 then
            Exit;
        Common := '';
        I := 1;
        while I <= Length(Res) do
        begin
            K := Pos(#10, Copy(Res, I, MaxInt));
            if K = 0 then
            begin
                Entry := Copy(Res, I, MaxInt);
                I := Length(Res) + 1;
            end
            else
            begin
                Entry := Copy(Res, I, K - 1);
                I := I + K;
            end;
            Entry := Trim(Entry);
            if Entry = '' then
                Continue;
            K := Pos('/', Entry);
            if K = 0 then
                Exit;
            Top := Copy(Entry, 1, K - 1);
            if Common = '' then
                Common := Top
            else if Common <> Top then
                Exit;
        end;
        Result := Common;
    end;
end;

{ Extract an archive into DstDir. Result = 0 on success. }
function Archive_Extract(const F, DstDir: string): Integer;
var
    U: TUnZipper;
    Res: string;
    LastExt, Inner: string;
begin
    Result := 1;
    if Is_Zip_File(F) then
    begin
        U := TUnZipper.Create;
        try
            U.FileName := F;
            U.OutputPath := DstDir;
            try
                U.UnZipAllFiles;
                Result := 0;
            except
                Result := 1;
            end;
        finally
            U.Free;
        end;
        Exit;
    end;
    LastExt := Get_Compound_Ext_Last(F);
    if Is_Tar_Suffix(F) and HaveTool('tar') then
        Result := RunTool('tar', ['-xf', F, '-C', DstDir], Res)
    else if LastExt = '7z' then
        Result := RunTool('7z', ['x', '-o' + DstDir, F], Res)
    else if LastExt = 'rar' then
    begin
        if HaveTool('unrar') then
            Result := RunTool('unrar', ['x', F, IncludeTrailingPathDelimiter(DstDir)], Res)
        else
            Result := 127;
    end
    else if (LastExt = 'gz') and HaveTool('gzip') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'gzip -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end
    else if (LastExt = 'bz2') and HaveTool('bzip2') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'bzip2 -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end
    else if (LastExt = 'xz') and HaveTool('xz') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'xz -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end
    else if (LastExt = 'zst') and HaveTool('zstd') then
    begin
        Inner := IncludeTrailingPathDelimiter(DstDir) + Name_Without_Ext(F);
        Result := RunTool('sh', ['-c', 'zstd -dc "$1" > "$2"', 'sh', F, Inner], Res);
    end;
end;

{ ------------------------------------------------------------------ }
{ Time helpers                                                        }
{ ------------------------------------------------------------------ }

{ File_Time: modified/created/accessed time of a file as TDateTime }
function File_Time(const F, Which: string): TDateTime;
var
    SB: TStat;
    Age: LongInt;
begin
    Result := 0;
    if Which = 'accessed' then
    begin
        if FpStat(F, SB) = 0 then
            Result := UnixToDateTime(SB.st_atime);
    end
    else if Which = 'created' then
    begin
        if FpStat(F, SB) = 0 then
            Result := UnixToDateTime(SB.st_ctime);
    end
    else
    begin
        Age := FileAge(F);
        if Age >= 0 then
            Result := FileDateToDateTime(Age);
    end;
end;

{ ------------------------------------------------------------------ }
{ File collection (FindFirst/FindNext walk)                           }
{ ------------------------------------------------------------------ }

{ Collect_Dir: recursively collect the files of one directory }
procedure Collect_Dir(const Dir: string; List: TStringList);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    Rc := FindFirst(IncludeTrailingPathDelimiter(Dir) + AllFilesMask, faAnyFile, SR);
    try
        while Rc = 0 do
        begin
            Full := IncludeTrailingPathDelimiter(Dir) + SR.Name;
            if (SR.Name <> '.') and (SR.Name <> '..') then
            begin
                if (SR.Attr and faDirectory) = faDirectory then
                begin
                    if DoRecursive then
                        Collect_Dir(Full, List);
                end
                else
                begin
                    if (not DoHidden) and (SR.Name[1] = '.') then
                        { skip hidden files }
                    else if (not DoLinks) and Is_Symlink(Full) then
                        { skip symlinks unless --links }
                    else
                        List.Add(Full);
                end;
            end;
            Rc := FindNext(SR);
        end;
    finally
        FindClose(SR);
    end;
end;

{ Collect_Files: build the global work list from the start directory }
procedure Collect_Files;
var
    Start: string;
begin
    Files.Clear;
    if SourceDir <> '' then
        Start := SourceDir
    else
        Start := GetCurrentDir;
    Collect_Dir(Start, Files);
    Files.Sort;
end;

{ Find_All_Files: recursively list every file below a directory }
procedure Find_All_Files(const Dir: string; List: TStringList);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    Rc := FindFirst(IncludeTrailingPathDelimiter(Dir) + AllFilesMask, faAnyFile, SR);
    try
        while Rc = 0 do
        begin
            Full := IncludeTrailingPathDelimiter(Dir) + SR.Name;
            if (SR.Name <> '.') and (SR.Name <> '..') then
            begin
                if (SR.Attr and faDirectory) = faDirectory then
                    Find_All_Files(Full, List)
                else
                    List.Add(Full);
            end;
            Rc := FindNext(SR);
        end;
    finally
        FindClose(SR);
    end;
end;

{ Remove_Tree: delete a whole directory tree }
procedure Remove_Tree(const Dir: string);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    Rc := FindFirst(IncludeTrailingPathDelimiter(Dir) + AllFilesMask, faAnyFile, SR);
    try
        while Rc = 0 do
        begin
            Full := IncludeTrailingPathDelimiter(Dir) + SR.Name;
            if (SR.Name <> '.') and (SR.Name <> '..') then
            begin
                if (SR.Attr and faDirectory) = faDirectory then
                    Remove_Tree(Full)
                else
                    DeleteFile(Full);
            end;
            Rc := FindNext(SR);
        end;
    finally
        FindClose(SR);
    end;
    RemoveDir(Dir);
end;

{ ------------------------------------------------------------------ }
{ Dynamic value engine (Resolve_Segment)                              }
{ ------------------------------------------------------------------ }

{ Media_Tier: size tier name (TINY..HUGE) for width x height }
function Media_Tier(const W, H: Integer): string;
begin
    if (W < 64) or (H < 64) then Result := 'TINY'
    else if (W < 128) or (H < 128) then Result := 'MINI'
    else if (W < 320) or (H < 320) then Result := 'SMALLER'
    else if (W < 640) or (H < 640) then Result := 'SMALL'
    else if (W < 1280) or (H < 1280) then Result := 'MEDIUM'
    else if (W < 1920) or (H < 1920) then Result := 'BIG'
    else if (W < 3840) or (H < 3840) then Result := 'BIGGER'
    else Result := 'HUGE';
end;

{ Media_Orient: orientation name (WIDE/HIGH/SQUARE) for width x height }
function Media_Orient(const W, H: Integer): string;
begin
    if W > H then Result := 'WIDE'
    else if W < H then Result := 'HIGH'
    else Result := 'SQUARE';
end;

{ Exif_Field: one metadata field of a file via exiftool }
function Exif_Field(const F, Field: string): string;
var
    Res: string;
begin
    Result := '';
    if RunTool('exiftool', ['-s3', '-' + Field, F], Res) = 0 then
        Result := Trim(Res);
end;

{ Video_Duration: video duration in seconds via ffprobe }
function Video_Duration(const F: string): string;
var
    Res: string;
    P: Integer;
begin
    Result := '';
    if RunTool('ffprobe', ['-v', 'quiet', '-show_entries', 'format=duration',
                           '-of', 'csv=p=0', F], Res) = 0 then
    begin
        Res := Trim(Res);
        P := Pos('.', Res);
        if P > 0 then
            Res := Copy(Res, 1, P - 1);
        Result := Res;
    end;
end;

{ Image_WxH: image width and height via identify }
function Image_WxH(const F: string; out W, H: Integer): Boolean;
var
    Res: string;
    P: Integer;
begin
    Result := False;
    W := 0;
    H := 0;
    if RunTool('identify', ['-format', '%w:%h', F], Res) <> 0 then
        Exit;
    Res := Trim(Res);
    P := Pos(':', Res);
    if P = 0 then
        Exit;
    W := StrToIntDef(Copy(Res, 1, P - 1), 0);
    H := StrToIntDef(Copy(Res, P + 1, MaxInt), 0);
    Result := (W > 0) and (H > 0);
end;

{ Underscore: replace spaces with underscores }
function Underscore(const S: string): string;
var
    I: Integer;
begin
    Result := S;
    for I := 1 to Length(Result) do
        if Result[I] = ' ' then
            Result[I] := '_';
end;

{ ================= TAGS MODULE ================= }

{ The 80 standard ID3v1 genres plus the Winamp extensions (0-125) }
const
    Genre_Table: array[0..125] of string = (
        'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk',
        'Grunge', 'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other',
        'Pop', 'R&B', 'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial',
        'Alternative', 'Ska', 'Death Metal', 'Pranks', 'Soundtrack',
        'Euro-Techno', 'Ambient', 'Trip-Hop', 'Vocal', 'Jazz+Funk', 'Fusion',
        'Trance', 'Classical', 'Instrumental', 'Acid', 'House', 'Game',
        'Sound Clip', 'Gospel', 'Noise', 'Alternative Rock', 'Bass', 'Soul',
        'Punk', 'Space', 'Meditation', 'Instrumental Pop', 'Instrumental Rock',
        'Ethnic', 'Gothic', 'Darkwave', 'Techno-Industrial', 'Electronic',
        'Pop-Folk', 'Eurodance', 'Dream', 'Southern Rock', 'Comedy', 'Cult',
        'Gangsta', 'Top 40', 'Christian Rap', 'Pop/Funk', 'Jungle',
        'Native US', 'Cabaret', 'New Wave', 'Psychadelic', 'Rave',
        'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal', 'Acid Punk', 'Acid Jazz',
        'Polka', 'Retro', 'Musical', 'Rock & Roll', 'Hard Rock', 'Folk',
        'Folk-Rock', 'National Folk', 'Swing', 'Fast Fusion', 'Bebob',
        'Latin', 'Revival', 'Celtic', 'Bluegrass', 'Avantgarde',
        'Gothic Rock', 'Progressive Rock', 'Psychedelic Rock',
        'Symphonic Rock', 'Slow Rock', 'Big Band', 'Chorus', 'Easy Listening',
        'Acoustic', 'Humour', 'Speech', 'Chanson', 'Opera', 'Chamber Music',
        'Sonata', 'Symphony', 'Booty Bass', 'Primus', 'Porn Groove', 'Satire',
        'Slow Jam', 'Club', 'Tango', 'Samba', 'Folklore', 'Ballad',
        'Power Ballad', 'Rhythmic Soul', 'Freestyle', 'Duet', 'Punk Rock',
        'Drum Solo', 'A cappella', 'Euro-House', 'Dance Hall');

{ Trim_Tags: strip NUL bytes and trailing spaces from a raw tag field }
function Trim_Tags(const S: string): string;
var
    T: string;
begin
    T := StringReplace(S, #0, '', [rfReplaceAll]);
    while (T <> '') and (T[Length(T)] = ' ') do
        Delete(T, Length(T), 1);
    Result := T;
end;

{ Latin1_To_Utf8: ISO-8859-1 bytes to UTF-8 text }
function Latin1_To_Utf8(const S: string): string;
var
    I: Integer;
    C: Byte;
begin
    Result := '';
    for I := 1 to Length(S) do
    begin
        C := Ord(S[I]);
        if C < 128 then
            Result := Result + S[I]
        else
            Result := Result + Chr($C0 or (C shr 6)) + Chr($80 or (C and $3F));
    end;
end;

{ Utf16_To_Utf8: UTF-16 bytes (with or without BOM) to UTF-8 text;
  BE selects big-endian when no BOM is present }
function Utf16_To_Utf8(const S: string; BE: Boolean): string;
var
    WS: WideString;
    I, N: Integer;
    W: Word;
    Swap: Boolean;
begin
    Result := '';
    N := Length(S) div 2;
    if N = 0 then
        Exit;
    Swap := False;
    SetLength(WS, N);
    for I := 0 to N - 1 do
    begin
        if BE then
            W := (Ord(S[I * 2 + 1]) shl 8) or Ord(S[I * 2 + 2])
        else
            W := (Ord(S[I * 2 + 2]) shl 8) or Ord(S[I * 2 + 1]);
        if (I = 0) and ((W = $FEFF) or (W = $FFFE)) then
        begin
            { byte order mark - remember the real order, skip the mark }
            if ((W = $FFFE) and (not BE)) or ((W = $FEFF) and BE) then
                Swap := True;
            continue;
        end;
        if Swap then
            W := (W shl 8) or (W shr 8);
        WS[I + 1] := WideChar(W);
    end;
    Result := Utf8Encode(WS);
end;

{ Id3v1_Present: true when the file ends with an ID3v1 tag }
function Id3v1_Present(const F: string): Boolean;
var
    FS: TFileStream;
    Buf: array[0..2] of Byte;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        if FS.Size < 128 then
            Exit;
        FS.Position := FS.Size - 128;
        FS.ReadBuffer(Buf, 3);
        Result := (Buf[0] = Ord('T')) and (Buf[1] = Ord('A')) and (Buf[2] = Ord('G'));
    finally
        FS.Free;
    end;
end;

{ Id3v1_Field: one ID3v1 field by name, empty when unusable }
function Id3v1_Field(const F, Field: string): string;
var
    FS: TFileStream;
    Buf: array[0..127] of Byte;
    Off, Len, I: Integer;
    Field_L: string;
begin
    Result := '';
    if not Id3v1_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := FS.Size - 128;
        FS.ReadBuffer(Buf, 128);
    finally
        FS.Free;
    end;
    Field_L := LowerCase(Field);
    if Field_L = 'track' then
    begin
        { track byte only valid when the comment zero-separator is there }
        if (Buf[125] = 0) and (Buf[126] <> 0) then
            Result := IntToStr(Buf[126]);
        Exit;
    end;
    if Field_L = 'genre' then
    begin
        if (Buf[127] < 255) and (Buf[127] <= 125) then
            Result := Genre_Table[Buf[127]]
        else if Buf[127] < 255 then
            Result := IntToStr(Buf[127]);
        Exit;
    end;
    if Field_L = 'title' then
    begin
        Off := 3;
        Len := 30;
    end
    else if Field_L = 'artist' then
    begin
        Off := 33;
        Len := 30;
    end
    else if Field_L = 'album' then
    begin
        Off := 63;
        Len := 30;
    end
    else if Field_L = 'year' then
    begin
        Off := 93;
        Len := 4;
    end
    else if Field_L = 'comment' then
    begin
        Off := 97;
        Len := 28;
    end
    else
        Exit;
    for I := Off to Off + Len - 1 do
        Result := Result + Chr(Buf[I]);
    Result := Trim_Tags(Result);
end;

{ Id3v1_Genre_Name: genre name for an index, empty when unknown }
function Id3v1_Genre_Name(Idx: Integer): string;
begin
    Result := '';
    if (Idx >= 0) and (Idx <= 125) then
        Result := Genre_Table[Idx];
end;

{ Id3v2_Present: true when the file starts with an ID3v2 tag }
function Id3v2_Present(const F: string): Boolean;
var
    FS: TFileStream;
    Buf: array[0..2] of Byte;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        if FS.Size < 10 then
            Exit;
        FS.ReadBuffer(Buf, 3);
        Result := (Buf[0] = Ord('I')) and (Buf[1] = Ord('D')) and (Buf[2] = Ord('3'));
    finally
        FS.Free;
    end;
end;

{ Id3v2_Major: ID3v2 major version, 0 when absent }
function Id3v2_Major(const F: string): Integer;
var
    FS: TFileStream;
    B: Byte;
begin
    Result := 0;
    if not Id3v2_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := 3;
        FS.ReadBuffer(B, 1);
        Result := B;
    finally
        FS.Free;
    end;
end;

{ Id3v2_Tag_Size: synchsafe size from the 10-byte header }
function Id3v2_Tag_Size(const F: string): Integer;
var
    FS: TFileStream;
    Buf: array[0..3] of Byte;
begin
    Result := 0;
    if not Id3v2_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := 6;
        FS.ReadBuffer(Buf, 4);
        Result := (Buf[0] shl 21) or (Buf[1] shl 14) or (Buf[2] shl 7) or Buf[3];
    finally
        FS.Free;
    end;
end;

{ Id3v2_Field: walk the frames, return the wanted text frame decoded }
function Id3v2_Field(const F, Frame: string): string;
var
    FS: TFileStream;
    Hdr: array[0..9] of Byte;
    Ver, TagSize, Off, EndOff, HdrLen, FSize, I: Integer;
    FID: string;
    Payload: string;
    Enc: Byte;
begin
    Result := '';
    if not Id3v2_Present(F) then
        Exit;
    Ver := Id3v2_Major(F);
    TagSize := Id3v2_Tag_Size(F);
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        Off := 10;
        EndOff := 10 + TagSize;
        while Off < EndOff do
        begin
            FS.Position := Off;
            if FS.Read(Hdr, 10) < 10 then
                Break;
            if Ver = 2 then
            begin
                { v2.2: 3-char frame id, 3-byte big-endian size, no flags }
                HdrLen := 6;
                FID := '';
                for I := 0 to 2 do
                    FID := FID + Chr(Hdr[I]);
                if not (Hdr[0] in [Ord('A')..'Z', Ord('0')..'9']) then
                    Break;
                FSize := (Hdr[3] shl 16) or (Hdr[4] shl 8) or Hdr[5];
            end
            else
            begin
                HdrLen := 10;
                FID := '';
                for I := 0 to 3 do
                    FID := FID + Chr(Hdr[I]);
                if not (Hdr[0] in [Ord('A')..'Z', Ord('0')..'9']) then
                    Break;
                if Ver >= 4 then
                    FSize := (Hdr[4] shl 21) or (Hdr[5] shl 14) or (Hdr[6] shl 7) or Hdr[7]
                else
                    FSize := (Hdr[4] shl 24) or (Hdr[5] shl 16) or (Hdr[6] shl 8) or Hdr[7];
            end;
            if (FSize <= 0) or (Off + HdrLen + FSize > FS.Size) then
                Break;

            if FID = Frame then
            begin
                SetLength(Payload, FSize);
                FS.Position := Off + HdrLen;
                FS.ReadBuffer(Payload[1], FSize);
                Enc := Ord(Payload[1]);
                Delete(Payload, 1, 1);
                case Enc of
                    1: Result := Trim_Tags(Utf16_To_Utf8(Payload, False));
                    2: Result := Trim_Tags(Utf16_To_Utf8(Payload, True));
                    0: Result := Trim_Tags(Latin1_To_Utf8(Payload));
                else
                    Result := Trim_Tags(Payload);
                end;
                Exit;
            end;
            Off := Off + HdrLen + FSize;
        end;
    finally
        FS.Free;
    end;
end;

{ Id3_Field: friendly name -> ID3v2 frames, then ID3v1 field }
function Id3_Field(const F, Field: string): string;
var
    Field_L: string;
begin
    Result := '';
    Field_L := LowerCase(Field);
    case Field_L of
        'title':
            Result := Id3v2_Field(F, 'TIT2');
        'artist':
            Result := Id3v2_Field(F, 'TPE1');
        'album':
            Result := Id3v2_Field(F, 'TALB');
        'year':
        begin
            Result := Id3v2_Field(F, 'TDRC');
            if Result = '' then
                Result := Id3v2_Field(F, 'TYER');
        end;
        'genre':
            Result := Id3v2_Field(F, 'TCON');
        'track':
            Result := Id3v2_Field(F, 'TRCK');
    else
        Exit;
    end;

    { v2.2 3-character ids }
    if Result = '' then
        case Field_L of
            'title': Result := Id3v2_Field(F, 'TT2');
            'artist': Result := Id3v2_Field(F, 'TP1');
            'album': Result := Id3v2_Field(F, 'TAL');
            'year': Result := Id3v2_Field(F, 'TYE');
            'genre': Result := Id3v2_Field(F, 'TCO');
            'track': Result := Id3v2_Field(F, 'TRK');
        end;

    { ID3v1 fallback }
    if Result = '' then
        Result := Id3v1_Field(F, Field_L);

    { genre: "(17)" or plain "17" -> genre name }
    if (Field_L = 'genre') and (Result <> '') then
    begin
        if (Length(Result) > 2) and (Result[1] = '(') then
            Result := Copy(Result, 2, Pos(')', Result) - 2);
        if Result = IntToStr(StrToIntDef(Result, -1)) then
        begin
            if Id3v1_Genre_Name(StrToIntDef(Result, -1)) <> '' then
                Result := Id3v1_Genre_Name(StrToIntDef(Result, -1));
        end;
    end;
end;

{ Tags_Sanitize: make one tag component safe as a directory name }
function Tags_Sanitize(const S: string): string;
var
    I: Integer;
begin
    Result := '';
    for I := 1 to Length(S) do
        if S[I] = ' ' then
            Result := Result + '_'
        else if not (S[I] in ['/', '\\', ':', '*', '?', '"', '<', '>', '|']) then
            Result := Result + S[I];
end;

{ Get_Audio_Tags_Dir: "<Artist>/<Year - Album>" composite, empty levels
  skipped, components sanitized }
function Get_Audio_Tags_Dir(const F: string): string;
var
    A, Y, Al, Sub: string;
begin
    Result := '';
    A := Tags_Sanitize(Id3_Field(F, 'artist'));
    Y := Id3_Field(F, 'year');
    Al := Tags_Sanitize(Id3_Field(F, 'album'));
    if (Y <> '') and (Al <> '') then
        Sub := Y + ' - ' + Al
    else
        Sub := Y + Al;
    if A <> '' then
        Result := A;
    if Sub <> '' then
    begin
        if Result <> '' then
            Result := Result + '/' + Sub
        else
            Result := Sub;
    end;
end;

{ =============== END TAGS MODULE =============== }

{ Resolve one dynamic value for file F.
  Returns 0 = ok (Text = value), 1 = failed, 2 = unknown -> literal. }
function Resolve_Segment(const Value, F: string; out Text: string): Integer;
var
    Mime, DT, Tmp: string;
    W, H: Integer;
    P: Integer;
begin
    Text := '';
    Result := 0;
    if Value = 'extension' then
    begin
        if Get_Compound_Ext(F, Tmp) then
            Text := Tmp
        else
            Text := Get_File_Ext(F);
    end
    else if Value = 'mime' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := Mime;
    end
    else if Value = 'mime-main' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := UpCase(MIME_Main(Mime));
    end
    else if Value = 'mime-sub' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := MIME_Sub(Mime);
    end
    else if Value = 'mime-ext' then
    begin
        Text := Get_MIME_Best_Extension(F);
        if Text = '' then
            Exit(1);
    end
    else if Value = 'year' then
        Text := FormatDateTime('yyyy', File_Time(F, 'modified'))
    else if (Value = 'created') or (Value = 'modified') or (Value = 'accessed') then
    begin
        DT := File_Time(F, Value);
        Text := FormatDateTime('yyyy-mm-dd', DT);
    end
    else if (Value = 'md5') or (Value = 'sha1') or (Value = 'sha256')
            or (Value = 'sha512') then
    begin
        Text := Hash_File(F, Value);
        if Text = '' then
            Exit(1);
    end
    else if Value = 'sha' then
    begin
        Text := Hash_File(F, 'sha256');
        if Text = '' then
            Exit(1);
    end
    else if Value = 'random' then
        Text := IntToStr(Random(100000))
    else if Value = 'size' then
        Text := IntToStr(Get_File_Size(F))
    else if Value = 'format' then
    begin
        if not Image_WxH(F, W, H) then
            Exit(1);
        Text := Media_Tier(W, H) + '-' + Media_Orient(W, H);
    end
    else if Value = 'duration' then
    begin
        Text := Video_Duration(F);
        if Text = '' then
            Exit(1);
    end
    else if (Value = 'id3') or (Value = 'audio') then
    begin
        Text := Get_Audio_Tags_Dir(F);
        if Text = '' then
            Exit(1);
    end
    else if Pos('id3-', Value) = 1 then
    begin
        Tmp := Id3_Field(F, Copy(Value, 5, MaxInt));
        if Tmp = '' then
            Exit(1);
        Text := Tags_Sanitize(Tmp);
    end
    else if Value = 'camera' then
    begin
        Text := Underscore(Exif_Field(F, 'Model'));
        if Text = '' then
            Exit(1);
    end
    else if Value = 'exifdate' then
    begin
        Tmp := Exif_Field(F, 'DateTimeOriginal');
        P := Pos(' ', Tmp);
        if P = 0 then
            Exit(1);
        Tmp := Copy(Tmp, 1, P - 1);
        for P := 1 to Length(Tmp) do
            if Tmp[P] = ':' then
                Tmp[P] := '-';
        Text := Tmp;
    end
    else if (Value = 'title') or (Value = 'long') or (Value = 'short') then
    begin
        Text := Exif_Field(F, 'Title');
        if Text = '' then
            Text := Get_Base_Name(F);
        Text := Underscore(Text);
    end
    else if Value = 'compressed' then
    begin
        Text := Archive_Main_Name(F);
        if Text = '' then
            Text := Get_Base_Name(F);
    end
    else if (Value = 'folder') or (Value = 'folder_name') then
        Text := ExtractFileName(ExtractFileDir(ExpandFileName(F)))
    else
        Result := 2;  { unknown -> treated as literal }
end;

{ Build one list of segments from a comma/plus separated option value }
procedure Build_Segments(const Spec, F: string; List: TStringList);
var
    Parts: TStringList;
    I: Integer;
    V, S: string;
    Rc: Integer;
begin
    Parts := TStringList.Create;
    try
        Parts.Delimiter := ',';
        Parts.StrictDelimiter := True;
        Parts.DelimitedText := StringReplace(Spec, '+', ',', [rfReplaceAll]);
        for I := 0 to Parts.Count - 1 do
        begin
            V := Trim(Parts[I]);
            if V = '' then
                Continue;
            Rc := Resolve_Segment(LowerCase(V), F, S);
            if Rc = 0 then
            begin
                if S <> '' then
                    List.Add(S);
            end
            else if Rc = 2 then
                List.Add(V);  { unknown value -> literal }
            { Rc = 1 -> failed, segment skipped }
        end;
    finally
        Parts.Free;
    end;
end;

{ Sanitize_Name: replace filesystem-unsafe characters with underscores }
function Sanitize_Name(const S: string): string;
var
    I: Integer;
begin
    Result := S;
    for I := 1 to Length(Result) do
        if CharInSet(Result[I], ['/', '\', ':', '*', '?', '"', '<', '>', '|']) then
            Result[I] := '_';
end;

{ Compute the new absolute path for file F }
function Build_Name(const F: string): string;
var
    Dirs, Subs: TStringList;
    NewDir, NewName, Ext, Suffix: string;
    I: Integer;
begin
    Dirs := TStringList.Create;
    Subs := TStringList.Create;
    try
        if DirList <> '' then
            Build_Segments(DirList, F, Dirs);
        if SubList <> '' then
            Build_Segments(SubList, F, Subs);
        if DoExif then
        begin
            if Resolve_Segment('camera', F, Suffix) = 0 then
                Dirs.Insert(0, Sanitize_Name(Suffix));
            if Resolve_Segment('exifdate', F, Suffix) = 0 then
                Dirs.Insert(1, Sanitize_Name(Suffix));
        end;

        { base name }
        if (RenameVal = 'sha') or (RenameVal = 'sha256') then
        begin
            NewName := Hash_File(F, 'sha256');
            if NewName = '' then
                NewName := Get_Base_Name(F);
        end
        else if RenameVal = 'md5' then
        begin
            NewName := Hash_File(F, 'md5');
            if NewName = '' then
                NewName := Get_Base_Name(F);
        end
        else if RenameVal = 'compressed' then
        begin
            NewName := Archive_Main_Name(F);
            if NewName = '' then
                NewName := Get_Base_Name(F);
        end
        else if (RenameVal = 'id3') or (RenameVal = 'audio') then
        begin
            NewName := Get_Audio_Tags_Dir(F);
            if NewName = '' then
                NewName := Get_Base_Name(F);
        end
        else if Pos('id3-', RenameVal) = 1 then
        begin
            NewName := Id3_Field(F, Copy(RenameVal, 5, MaxInt));
            if NewName = '' then
                NewName := Get_Base_Name(F);
        end
        else
            NewName := Get_Base_Name(F);

        { extension }
        if ExtensionVal = 'none' then
            Ext := ''
        else if ExtensionVal = 'mime' then
        begin
            Suffix := Detect_MIME(F);
            if Suffix <> '' then
                Ext := '.' + StringReplace(Suffix, '/', '.', [rfReplaceAll])
            else
                Ext := '.' + Get_File_Ext(F);
        end
        else if ExtensionVal = 'mime-sub' then
        begin
            Suffix := MIME_Sub(Detect_MIME(F));
            if Suffix <> '' then
                Ext := '.' + Suffix
            else
                Ext := '.' + Get_File_Ext(F);
        end
        else if ExtensionVal = 'mime-ext' then
        begin
            Suffix := Get_MIME_Best_Extension(F);
            if Suffix <> '' then
                Ext := '.' + Suffix
            else
                Ext := '.' + Get_File_Ext(F);
        end
        else if ExtensionVal = 'mime-main' then
        begin
            Suffix := MIME_Main(Detect_MIME(F));
            if Suffix <> '' then
                Ext := '.' + LowerCase(Suffix)
            else
                Ext := '.' + Get_File_Ext(F);
        end
        else if ExtensionVal = 'lower' then
            Ext := '.' + LowerCase(Get_File_Ext(F))
        else if ExtensionVal = 'upper' then
            Ext := '.' + UpCase(Get_File_Ext(F))
        else if ExtensionVal = 'extension' then
            Ext := '.' + Get_File_Ext(F)
        else if ExtensionVal = '' then
            Ext := ''
        else
            Ext := '.' + ExtensionVal;

        NewDir := TargetDir;
        for I := 0 to Dirs.Count - 1 do
            NewDir := IncludeTrailingPathDelimiter(NewDir) + Sanitize_Name(Dirs[I]);
        for I := 0 to Subs.Count - 1 do
            NewDir := IncludeTrailingPathDelimiter(NewDir) + Sanitize_Name(Subs[I]);

        Result := IncludeTrailingPathDelimiter(NewDir) + Sanitize_Name(NewName) + Ext;
    finally
        Dirs.Free;
        Subs.Free;
    end;
end;

{ Collision handling: append ~(N) for non-destructive modes }
function Unique_Target(const T: string): string;
var
    N: Integer;
    Base, Ext: string;
begin
    Result := T;
    if (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred') then
        Exit;
    if not FileExists(Result) then
        Exit;
    Base := ChangeFileExt(T, '');
    Ext := Copy(T, Length(Base) + 1, MaxInt);
    N := 1;
    while FileExists(Base + '~(' + IntToStr(N) + ')' + Ext) do
        Inc(N);
    Result := Base + '~(' + IntToStr(N) + ')' + Ext;
end;

{ ------------------------------------------------------------------ }
{ Temp dirs (--decompress)                                            }
{ ------------------------------------------------------------------ }

{ Make_Temp_Dir: create a unique temporary directory }
function Make_Temp_Dir: string;
var
    Base, D: string;
    N: Integer;
begin
    Base := GetEnvironmentVariable('TMPDIR');
    if Base = '' then
        Base := '/tmp';
    N := 0;
    repeat
        D := IncludeTrailingPathDelimiter(Base) + 'sort.' + IntToStr(GetTickCount64)
             + '.' + IntToStr(N);
        Inc(N);
    until CreateDir(D) or (N > 100);
    Result := D;
end;

{ ------------------------------------------------------------------ }
{ Per-file processing                                                 }
{ ------------------------------------------------------------------ }

{ Process_File: process one file according to the active mode }
procedure Process_File(const F: string); forward;

{ Extract to a temp dir, process the contents, then apply the mode to
  the archive itself (same contract as the shell Process_Archive). }
function Process_Archive(const F: string): Integer;
var
    Tmp, Inner, Saved: string;
    List: TStringList;
    I: Integer;
    Rc: Integer;
begin
    Result := 0;
    if DecompressDepth >= 8 then
        Exit(1);
    Tmp := Make_Temp_Dir;
    Rc := Archive_Extract(F, Tmp);
    if Rc <> 0 then
    begin
        Out_Err(Tf(Tr('FAILED) %s - could not extract (rc %s)'), [F, IntToStr(Rc)]));
        Bump(CountFailed);
        Exit(1);
    end;
    Saved := Modus;
    if Modus <> 'print' then
        Modus := 'copy';
    List := TStringList.Create;
    try
        Find_All_Files(Tmp, List);
        List.Sort;
        for I := 0 to List.Count - 1 do
        begin
            DecompressDepth := DecompressDepth + 1;
            Process_File(List[I]);
            DecompressDepth := DecompressDepth - 1;
        end;
    finally
        List.Free;
    end;
    Modus := Saved;
    Bump(CountExtracted);
    { fate of the archive itself }
    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', Tf(Tr('EXTRACT(%s): %s <=> delete archive'),
                   [IntToStr(CountExtracted), F]));
        Bump(CountPreview);
    end
    else if Modus = 'trash' then
    begin
        Rc := Trash_File(F, Inner);
        if Rc = 0 then
            Bump(CountTrashed)
        else
        begin
            Out_Err(Tf(Tr('FAILED) trash %s'), [F]));
            Bump(CountFailed);
        end;
    end
    else if Modus = 'shred' then
    begin
        Shred_File(F);
        Bump(CountShredded);
    end
    else
    begin
        DeleteFile(F);
        Bump(CountRemoved);
    end;
    Remove_Tree(Tmp);
end;

{ Looks_Like_Archive: true when the file name looks like an archive (zip/tar/7z/rar/...) }
function Looks_Like_Archive(const F: string): Boolean;
var
    E: string;
begin
    E := LowerCase(Get_File_Ext(F));
    Result := Is_Zip_File(F) or Is_Tar_Suffix(F) or (E = '7z') or (E = 'rar')
              or (E = 'gz') or (E = 'bz2') or (E = 'xz') or (E = 'zst');
end;

{ Process_File: process one file according to the active mode }
procedure Process_File(const F: string);
var
    Target, Tmp: string;
    Rc: Integer;
begin
    if TypeFilter <> '' then
    begin
        Tmp := Detect_MIME(F);
        if Pos(LowerCase(TypeFilter), LowerCase(Tmp)) = 0 then
        begin
            Bump(CountSkipped);
            Exit;
        end;
    end;

    if DoDecompress and Looks_Like_Archive(F) then
    begin
        Process_Archive(F);
        Exit;
    end;

    Target := Build_Name(F);

    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', F + ' -> ' + Target);
        Bump(CountPreview);
        Exit;
    end;

    if (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred') then
    begin
        { Bash reference semantics: act on the calculated TARGET, not the source }
        if not FileExists(Target) then
        begin
            Out_Err(Tf(Tr('FAILED) target not found: %s'), [Target]));
            Bump(CountFailed);
            Exit;
        end;
        if Modus = 'remove' then
        begin
            if DeleteFile(Target) then
            begin
                Out_Tagged('REMOVED', Target);
                Bump(CountRemoved);
                Out_Log('rm ' + Target);
            end
            else
            begin
                Out_Err(Tf(Tr('FAILED) rm %s'), [Target]));
                Bump(CountFailed);
            end;
        end
        else if Modus = 'trash' then
        begin
            Rc := Trash_File(Target, Tmp);
            if Rc = 0 then
            begin
                Out_Tagged('TRASHED', Target);
                Bump(CountTrashed);
            end
            else
            begin
                Out_Err(Tf(Tr('FAILED) trash %s (rc %s)'), [Target, IntToStr(Rc)]));
                Bump(CountFailed);
            end;
        end
        else
        begin
            Shred_File(Target);
            Out_Tagged('SHREDDED', Target);
            Bump(CountShredded);
        end;
        Exit;
    end;

    { copy / move }
    if (Target = F) or (ExpandFileName(Target) = ExpandFileName(F)) then
    begin
        Out_Tagged('SKIPPED', F + ' (source = target)');
        Bump(CountSkipped);
        Exit;
    end;
    if FileExists(Target) then
    begin
        if DoReplace then
            DeleteFile(Target)
        else
            Target := Unique_Target(Target);
    end;
    if not ForceDirectories(ExtractFileDir(Target)) then
    begin
            Out_Err(Tf(Tr('FAILED) mkdir %s'), [ExtractFileDir(Target)]));
        Bump(CountFailed);
        Exit;
    end;
    if Modus = 'move' then
    begin
        if Move_File(F, Target) then
        begin
            Out_Tagged('MOVED', F + ' -> ' + Target);
            Bump(CountMoved);
            Out_Log('mv "' + F + '" "' + Target + '"');
            if UndoFile <> '' then
                UndoLines.Add('mv "' + Target + '" "' + F + '"');
        end
        else
        begin
            Out_Err(Tf(Tr('FAILED) move %s'), [F]));
            Bump(CountFailed);
        end;
    end
    else
    begin
        if Copy_File(F, Target) then
        begin
            Out_Tagged('COPIED', F + ' -> ' + Target);
            Bump(CountCopied);
            Out_Log('cp "' + F + '" "' + Target + '"');
            if UndoFile <> '' then
                UndoLines.Add('rm -f "' + Target + '"');
        end
        else
        begin
            Out_Err(Tf(Tr('FAILED) copy %s'), [F]));
            Bump(CountFailed);
        end;
    end;

    { --strip: remove EXIF from the processed target }
    if DoStrip and HaveTool('exiftool') then
        RunTool('exiftool', ['-all=', '-overwrite_original', Target], Tmp);

    if PauseSec > 0 then
        Sleep(PauseSec * 1000);
end;

{ ------------------------------------------------------------------ }
{ Thread pool (TThread)                                               }
{ ------------------------------------------------------------------ }

{ TSortThread: worker thread: take the next index and process that file }
procedure TSortThread.Execute;
var
    Idx: Integer;
    F: string;
begin
    while True do
    begin
        Lock.Enter;
        try
            Idx := NextIdx;
            NextIdx := NextIdx + 1;
        finally
            Lock.Leave;
        end;
        if Idx >= Files.Count then
            Break;
        F := Files[Idx];
        Process_File(F);
    end;
end;

{ Run_Threads: run the work list: thread pool when --jobs > 1, else sequential }
procedure Run_Threads;
var
    I, N: Integer;
    Workers: array of TSortThread;
begin
    if (JobCount <= 1) or (Files.Count < 2) then
    begin
        for I := 0 to Files.Count - 1 do
            Process_File(Files[I]);
        Exit;
    end;
    NextIdx := 0;
    N := Min(JobCount, Files.Count);
    SetLength(Workers, N);
    for I := 0 to N - 1 do
        Workers[I] := TSortThread.Create(True);
    for I := 0 to N - 1 do
        Workers[I].Start;
    for I := 0 to N - 1 do
    begin
        Workers[I].WaitFor;
        Workers[I].Free;
    end;
end;

{ ------------------------------------------------------------------ }
{ Self test (--self-test)                                             }
{ ------------------------------------------------------------------ }

{ Self_Test: built-in self test (hash vectors, temp-file write) }
function Self_Test: Boolean;
var
    Ok: Boolean;
    D, F1: string;
    SL: TStringList;
begin
    Ok := True;
    WriteLn('self-test: md5("abc") = ', MD5Print(MD5String('abc')));
    if MD5Print(MD5String('abc')) <> '900150983cd24fb0d6963f7d28e17f72' then
        Ok := False;
    WriteLn('self-test: sha1("abc") = ', SHA1Print(SHA1String('abc')));
    if SHA1Print(SHA1String('abc')) <> 'a9993e364706816aba3e25717850c26c9cd0d89d' then
        Ok := False;
    D := Make_Temp_Dir;
    F1 := IncludeTrailingPathDelimiter(D) + 't.txt';
    SL := TStringList.Create;
    try
        SL.Add('hello');
        SL.SaveToFile(F1);
        if FileExists(F1) then
            WriteLn('self-test: temp-file write OK')
        else
            Ok := False;
    finally
        SL.Free;
    end;
    Remove_Tree(D);
    if Ok then
        WriteLn('self-test: PASS')
    else
        WriteLn('self-test: FAIL');
    Result := Ok;
end;

{ ------------------------------------------------------------------ }
{ Usage / Help                                                        }
{ ------------------------------------------------------------------ }

{ ------------------------------------------------------------------ }
{ i18n: --lang=XX - 20 built-in UI languages (default: en)            }
{ ------------------------------------------------------------------ }
const
    LangCodes: array[1..20] of String = (
        'en', 'zh', 'hi', 'es', 'fr', 'ar', 'bn', 'pt', 'ru', 'ur',
        'id', 'de', 'ja', 'tr', 'ko', 'vi', 'it', 'pl', 'nl', 'fa');

var
    Lang: String;

{ Lang_Name: native name of a language code }
function Lang_Name(const Code: String): String;
begin
    if Code = 'en' then Result := 'English'
    else if Code = 'zh' then Result := 'Chinese (Mandarin) / 中文'
    else if Code = 'hi' then Result := 'Hindi / हिन्दी'
    else if Code = 'es' then Result := 'Spanish / Español'
    else if Code = 'fr' then Result := 'French / Français'
    else if Code = 'ar' then Result := 'Arabic / العربية'
    else if Code = 'bn' then Result := 'Bengali / বাংলা'
    else if Code = 'pt' then Result := 'Portuguese / Português'
    else if Code = 'ru' then Result := 'Russian / Русский'
    else if Code = 'ur' then Result := 'Urdu / اردو'
    else if Code = 'id' then Result := 'Indonesian / Bahasa Indonesia'
    else if Code = 'de' then Result := 'German / Deutsch'
    else if Code = 'ja' then Result := 'Japanese / 日本語'
    else if Code = 'tr' then Result := 'Turkish / Türkçe'
    else if Code = 'ko' then Result := 'Korean / 한국어'
    else if Code = 'vi' then Result := 'Vietnamese / Tiếng Việt'
    else if Code = 'it' then Result := 'Italian / Italiano'
    else if Code = 'pl' then Result := 'Polish / Polski'
    else if Code = 'nl' then Result := 'Dutch / Nederlands'
    else if Code = 'fa' then Result := 'Persian / فارسی'
    else Result := Code;
end;

{ Tr: translate an English UI string according to Lang }
function Tr(const S: String): String;
begin
    if Lang = 'en' then
        Result := S
    else if Lang = 'zh' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := '用法: sort [选项] [目录...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := '请尝试 sort --help 查看完整选项列表。'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder 文件整理器 - Sort.sh v21 的 FreePascal 翻译'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= 的快捷方式'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove 的快捷方式'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= 的快捷方式'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      目录层级, 逗号/加号分隔:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         仅处理 MIME 类型包含 VALUE 的文件'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         排序树的基础目录(默认: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          递归遍历所给目录的全部深度'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             包含隐藏文件和目录'
        else if S = '  --links            include symbolic links' then Result := '  --links              包含符号链接'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          每个文件处理后等待'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             线程池大小(默认: nproc,最小 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           将每个操作追加一行记录到 FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        写入撤销脚本(默认: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            强制彩色输出(在 tty 上自动检测)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         先解压压缩包到临时目录,再整理其中的内容'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  名称 = 压缩包内的主目录/单个文件'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               为图像添加 <相机>/<YYYY-MM-DD> 层级'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              复制/移动后清除目标中的 EXIF/GPS 元数据'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            覆盖已存在的目标,否则使用唯一的 ~(N) 名称'
        else if S = 'Found %s file(s)' then Result := '找到 %s 个文件'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> 删除压缩包'
        else if S = 'Unknown option: %s' then Result := '未知选项: %s'
        else if S = 'Invalid --mode: %s' then Result := '无效的 --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash 需要 trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := '找不到源目录: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := '不支持的语言: %s (见 --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := '可用语言 (--lang=XX):'
        else if S = 'Summary' then Result := '摘要'
        else if S = 'Copied : %s' then Result := '已复制 : %s'
        else if S = 'Moved  : %s' then Result := '已移动  : %s'
        else if S = 'Removed: %s' then Result := '已删除: %s'
        else if S = 'Trashed  : %s' then Result := '回收站 : %s'
        else if S = 'Shredded : %s' then Result := '粉碎   : %s'
        else if S = 'Extracted: %s' then Result := '已解压: %s'
        else if S = 'Preview: %s' then Result := '预览: %s'
        else if S = 'Skipped: %s' then Result := '已跳过: %s'
        else if S = 'Failed : %s' then Result := '失败   : %s'
        else if S = 'Undo script written: %s' then Result := '撤销脚本已写入: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := '失败) %s - 无法解压 (rc %s)'
        else if S = 'FAILED) trash %s' then Result := '失败) 回收站 %s'
        else if S = 'FAILED) rm %s' then Result := '失败) 删除 %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := '失败) 回收站 %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := '失败) 创建目录 %s'
        else if S = 'FAILED) move %s' then Result := '失败) 移动 %s'
        else if S = 'FAILED) copy %s' then Result := '失败) 复制 %s'
        else if S = 'MODES:' then Result := '模式:'
        else if S = 'STRUCTURE:' then Result := '目标和命名:'
        else if S = 'FILTERS / SCOPE:' then Result := '过滤和处理:'
        else if S = 'ARCHIVES:' then Result := '压缩包:'
        else if S = 'EXTRAS:' then Result := '输出和安全:'
        else if S = 'LANGUAGES:' then Result := '语言:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          界面语言 (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             显示语言列表'
        else Result := S;
    end
    else if Lang = 'hi' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'उपयोग: sort [विकल्प] [निर्देशिका...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'पूरी विकल्प सूची के लिए sort --help आज़माएँ।'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder फ़ाइल आयोजक - Sort.sh v21 का FreePascal अनुवाद'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= के शॉर्टकट'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove का शॉर्टकट'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= के शॉर्टकट'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      निर्देशिका स्तर, अल्पविराम/प्लस से अलग:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         केवल वे फ़ाइलें जिनके MIME प्रकार में VALUE है'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         क्रमबद्ध वृक्ष की आधार निर्देशिका (डिफ़ॉल्ट: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          दी गई निर्देशिकाओं को पूरी गहराई तक चलें'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             छिपी फ़ाइलें और निर्देशिकाएँ शामिल करें'
        else if S = '  --links            include symbolic links' then Result := '  --links              प्रतीकात्मक लिंक शामिल करें'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          हर फ़ाइल के बाद प्रतीक्षा करें'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             थ्रेड पूल आकार (डिफ़ॉल्ट: nproc, न्यूनतम 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           हर क्रिया की एक पंक्ति FILE में जोड़ें'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        पूर्ववत स्क्रिप्ट लिखें (डिफ़ॉल्ट: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            रंगीन आउटपुट बाध्य करें (tty पर स्वतः पहचाना गया)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         संग्रहों को अस्थायी निर्देशिका में निकालें और सामग्री क्रमबद्ध करें'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  नाम = संग्रह के अंदर मुख्य निर्देशिका / एकल फ़ाइल'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               छवियों के लिए <कैमरा>/<YYYY-MM-DD> स्तर जोड़ें'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              कॉपी/मूव के बाद लक्ष्यों से EXIF/GPS मेटाडेटा हटाएँ'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            मौजूदा लक्ष्यों पर लिखें, अन्यथा अद्वितीय ~(N) नाम'
        else if S = 'Found %s file(s)' then Result := '%s फ़ाइल(ें) मिलीं'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> संग्रह हटाएँ'
        else if S = 'Unknown option: %s' then Result := 'अज्ञात विकल्प: %s'
        else if S = 'Invalid --mode: %s' then Result := 'अमान्य --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash को trash-put (trash-cli) चाहिए'
        else if S = 'Source directory not found: %s' then Result := 'स्रोत निर्देशिका नहीं मिली: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'असमर्थित भाषा: %s (--lang देखें)'
        else if S = 'Available languages (--lang=XX):' then Result := 'उपलब्ध भाषाएँ (--lang=XX):'
        else if S = 'Summary' then Result := 'सारांश'
        else if S = 'Copied : %s' then Result := 'कॉपी : %s'
        else if S = 'Moved  : %s' then Result := 'मूव  : %s'
        else if S = 'Removed: %s' then Result := 'हटाए: %s'
        else if S = 'Trashed  : %s' then Result := 'ट्रैश   : %s'
        else if S = 'Shredded : %s' then Result := 'श्रेड   : %s'
        else if S = 'Extracted: %s' then Result := 'निकाले: %s'
        else if S = 'Preview: %s' then Result := 'पूर्वावलोकन: %s'
        else if S = 'Skipped: %s' then Result := 'छोड़े: %s'
        else if S = 'Failed : %s' then Result := 'विफल : %s'
        else if S = 'Undo script written: %s' then Result := 'पूर्ववत स्क्रिप्ट लिखी गई: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'विफल) %s - निकाल नहीं सका (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'विफल) ट्रैश %s'
        else if S = 'FAILED) rm %s' then Result := 'विफल) हटाएँ %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'विफल) ट्रैश %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'विफल) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'विफल) स्थानांतरण %s'
        else if S = 'FAILED) copy %s' then Result := 'विफल) प्रतिलिपि %s'
        else if S = 'MODES:' then Result := 'मोड:'
        else if S = 'STRUCTURE:' then Result := 'गंतव्य और नामकरण:'
        else if S = 'FILTERS / SCOPE:' then Result := 'फ़िल्टरिंग और प्रोसेसिंग:'
        else if S = 'ARCHIVES:' then Result := 'संग्रह:'
        else if S = 'EXTRAS:' then Result := 'आउटपुट और सुरक्षा:'
        else if S = 'LANGUAGES:' then Result := 'भाषाएँ:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          UI भाषा (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             भाषा सूची दिखाएँ'
        else Result := S;
    end
    else if Lang = 'es' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Uso: sort [OPCIONES] [DIR...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Pruebe sort --help para la lista completa de opciones.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Organizador de archivos Ejder - traducción FreePascal de Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      atajos de --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  atajo de --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    atajos de --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      niveles de directorio, separados por coma/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Solo archivos cuyo tipo MIME contenga VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Directorio base del árbol clasificado (predeterminado: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Recorre los directorios dados a profundidad completa'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Incluye archivos y directorios ocultos'
        else if S = '  --links            include symbolic links' then Result := '  --links              Incluye enlaces simbólicos'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Espera tras cada archivo'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Tamaño del grupo de hilos (predeterminado: nproc, mín 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Añade una línea por acción a FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Escribe un script de deshacer (predeterminado: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Fuerza salida con color (autodetectado en una tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Extrae archivos comprimidos a un dir temporal y clasifica el contenido'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Nombre = dir principal / archivo único dentro del comprimido'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Añade niveles <Cámara>/<YYYY-MM-DD> para imágenes'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Elimina metadatos EXIF/GPS de los destinos tras copiar/mover'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Sobrescribe destinos existentes, si no nombre único ~(N)'
        else if S = 'Found %s file(s)' then Result := 'Se encontraron %s archivo(s)'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> borrar el archivo'
        else if S = 'Unknown option: %s' then Result := 'Opción desconocida: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode no válido: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash necesita trash-put (trash-cli) instalado'
        else if S = 'Source directory not found: %s' then Result := 'Directorio de origen no encontrado: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Idioma no admitido: %s (vea --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Idiomas disponibles (--lang=XX):'
        else if S = 'Summary' then Result := 'Resumen'
        else if S = 'Copied : %s' then Result := 'Copiados : %s'
        else if S = 'Moved  : %s' then Result := 'Movidos  : %s'
        else if S = 'Removed: %s' then Result := 'Eliminados: %s'
        else if S = 'Trashed  : %s' then Result := 'Papelera : %s'
        else if S = 'Shredded : %s' then Result := 'Destruidos: %s'
        else if S = 'Extracted: %s' then Result := 'Extraídos: %s'
        else if S = 'Preview: %s' then Result := 'Vista previa: %s'
        else if S = 'Skipped: %s' then Result := 'Omitidos: %s'
        else if S = 'Failed : %s' then Result := 'Fallidos : %s'
        else if S = 'Undo script written: %s' then Result := 'Script de deshacer escrito: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'FALLO) %s - no se pudo extraer (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'FALLO) papelera %s'
        else if S = 'FAILED) rm %s' then Result := 'FALLO) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'FALLO) papelera %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'FALLO) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'FALLO) mover %s'
        else if S = 'FAILED) copy %s' then Result := 'FALLO) copiar %s'
        else if S = 'MODES:' then Result := 'Modos:'
        else if S = 'STRUCTURE:' then Result := 'Destino y nombres:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filtrado y procesamiento:'
        else if S = 'ARCHIVES:' then Result := 'Archivos comprimidos:'
        else if S = 'EXTRAS:' then Result := 'Salida y seguridad:'
        else if S = 'LANGUAGES:' then Result := 'Idiomas:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Idioma de la interfaz (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Muestra la lista de idiomas'
        else Result := S;
    end
    else if Lang = 'fr' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Utilisation : sort [OPTIONS] [DIR...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Essayez ’sort --help’ pour la liste complète des options.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Organiseur de fichiers Ejder - traduction FreePascal de Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      raccourcis de --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  raccourci de --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    raccourcis de --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      niveaux de répertoires, séparés par virgule/+ :'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Seulement les fichiers dont le type MIME contient VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Répertoire de base de l’arbre classé (défaut : .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Parcourt les répertoires fournis sur toute la profondeur'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Inclut les fichiers et répertoires cachés'
        else if S = '  --links            include symbolic links' then Result := '  --links              Inclut les liens symboliques'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Attend après chaque fichier'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Taille du pool de threads (défaut : nproc, min 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Ajoute une ligne par action à FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Écrit un script d’annulation (défaut : sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Force la sortie colorée (autodétectée sur un tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Extrait les archives vers un répertoire temporaire et classe le contenu'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Nom = répertoire principal / fichier unique dans l’archive'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Ajoute des niveaux <Appareil>/<AAAA-MM-JJ> pour les images'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Supprime les métadonnées EXIF/GPS des cibles après copie/déplacement'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Écrase les cibles existantes, sinon nom unique ~(N)'
        else if S = 'Found %s file(s)' then Result := '%s fichier(s) trouvé(s)'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s) : %s <=> supprimer l’archive'
        else if S = 'Unknown option: %s' then Result := 'Option inconnue : %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode non valide : %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash requiert trash-put (trash-cli) installé'
        else if S = 'Source directory not found: %s' then Result := 'Répertoire source introuvable : %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Langue non prise en charge : %s (voir --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Langues disponibles (--lang=XX) :'
        else if S = 'Summary' then Result := 'Résumé'
        else if S = 'Copied : %s' then Result := 'Copiés : %s'
        else if S = 'Moved  : %s' then Result := 'Déplacés : %s'
        else if S = 'Removed: %s' then Result := 'Supprimés : %s'
        else if S = 'Trashed  : %s' then Result := 'Corbeille : %s'
        else if S = 'Shredded : %s' then Result := 'Détruits  : %s'
        else if S = 'Extracted: %s' then Result := 'Extraits : %s'
        else if S = 'Preview: %s' then Result := 'Aperçus : %s'
        else if S = 'Skipped: %s' then Result := 'Ignorés : %s'
        else if S = 'Failed : %s' then Result := 'Échoués : %s'
        else if S = 'Undo script written: %s' then Result := 'Script d’annulation écrit : %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'ÉCHEC) %s - extraction impossible (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'ÉCHEC) corbeille %s'
        else if S = 'FAILED) rm %s' then Result := 'ÉCHEC) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'ÉCHEC) corbeille %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'ÉCHEC) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'ÉCHEC) déplacement %s'
        else if S = 'FAILED) copy %s' then Result := 'ÉCHEC) copie %s'
        else if S = 'MODES:' then Result := 'Modes:'
        else if S = 'STRUCTURE:' then Result := 'Destination et nommage:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filtrage et traitement:'
        else if S = 'ARCHIVES:' then Result := 'Archives:'
        else if S = 'EXTRAS:' then Result := 'Sortie et sécurité:'
        else if S = 'LANGUAGES:' then Result := 'Langues:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Langue de l’interface (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Affiche la liste des langues'
        else Result := S;
    end
    else if Lang = 'ar' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'الاستخدام: sort [خيارات] [دليل...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'جرّب sort --help للحصول على قائمة الخيارات الكاملة.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'منظم ملفات Ejder - ترجمة FreePascal لـ Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      اختصارات لـ --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  اختصار لـ --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    اختصارات لـ --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      مستويات الدليل، مفصولة بفاصلة/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         فقط الملفات التي يحتوي نوع MIME فيها على VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         الدليل الأساسي لشجرة الترتيب (افتراضي: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          يجول الأدلة المعطاة بعمق كامل'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             يشمل الملفات والأدلة المخفية'
        else if S = '  --links            include symbolic links' then Result := '  --links              يشمل الروابط الرمزية'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          ينتظر بعد كل ملف'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             حجم مجموعة الخيوط (افتراضي: nproc، أدنى 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           يضيف سطرًا لكل عملية إلى FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        يكتب سكربت تراجع (افتراضي: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            يجبر المخرجات الملونة (تُكتشف تلقائيًا على tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         يستخرج الأرشيفات إلى دليل مؤقت ويرتِّب المحتويات'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  الاسم = الدليل الرئيس / الملف الوحيد داخل الأرشيف'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               يضيف مستويات <الكاميرا>/<YYYY-MM-DD> للصور'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              يزيل بيانات EXIF/GPS الوصفية من الأهداف بعد النسخ/النقل'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            يستبدل الأهداف الموجودة، وإلا اسم فريد ~(N)'
        else if S = 'Found %s file(s)' then Result := 'تم العثور على %s ملف(ات)'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> حذف الأرشيف'
        else if S = 'Unknown option: %s' then Result := 'خيار غير معروف: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode غير صالح: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash يحتاج trash-put (trash-cli) مثبتًا'
        else if S = 'Source directory not found: %s' then Result := 'الدليل المصدر غير موجود: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'لغة غير مدعومة: %s (انظر --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'اللغات المتاحة (--lang=XX):'
        else if S = 'Summary' then Result := 'الملخص'
        else if S = 'Copied : %s' then Result := 'منسوخ : %s'
        else if S = 'Moved  : %s' then Result := 'منقول  : %s'
        else if S = 'Removed: %s' then Result := 'محذوف: %s'
        else if S = 'Trashed  : %s' then Result := 'المهملات: %s'
        else if S = 'Shredded : %s' then Result := 'تمزيق  : %s'
        else if S = 'Extracted: %s' then Result := 'مستخرج: %s'
        else if S = 'Preview: %s' then Result := 'معاينة: %s'
        else if S = 'Skipped: %s' then Result := 'متخطى: %s'
        else if S = 'Failed : %s' then Result := 'فاشل : %s'
        else if S = 'Undo script written: %s' then Result := 'تمت كتابة سكربت التراجع: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'فشل) %s - تعذر الاستخراج (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'فشل) مهملات %s'
        else if S = 'FAILED) rm %s' then Result := 'فشل) حذف %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'فشل) مهملات %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'فشل) إنشاء دليل %s'
        else if S = 'FAILED) move %s' then Result := 'فشل) نقل %s'
        else if S = 'FAILED) copy %s' then Result := 'فشل) نسخ %s'
        else if S = 'MODES:' then Result := 'الأوضاع:'
        else if S = 'STRUCTURE:' then Result := 'الوجهة والتسمية:'
        else if S = 'FILTERS / SCOPE:' then Result := 'التصفية والمعالجة:'
        else if S = 'ARCHIVES:' then Result := 'الأرشيفات:'
        else if S = 'EXTRAS:' then Result := 'المخرجات والسلامة:'
        else if S = 'LANGUAGES:' then Result := 'اللغات:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          لغة الواجهة (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             اطبع قائمة اللغات'
        else Result := S;
    end
    else if Lang = 'bn' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'ব্যবহার: sort [বিকল্প] [ডিরেক্টরি...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'সম্পূর্ণ বিকল্প তালিকার জন্য sort --help দেখুন।'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder ফাইল সংগঠক - Sort.sh v21 এর FreePascal অনুবাদ'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= এর সংক্ষিপ্ত রূপ'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove এর সংক্ষিপ্ত রূপ'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= এর সংক্ষিপ্ত রূপ'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      ডিরেক্টরি স্তর, কমা/প্লাস দ্বারা পৃথক:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         শুধু যেসব ফাইলের MIME ধরনে VALUE আছে'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         সাজানো বৃক্ষের ভিত্তি ডিরেক্টরি (ডিফল্ট: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          দেওয়া ডিরেক্টরিগুলো পূর্ণ গভীরতায় ঘোরে'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             লুকানো ফাইল ও ডিরেক্টরি অন্তর্ভুক্ত করে'
        else if S = '  --links            include symbolic links' then Result := '  --links              সিম্বলিক লিঙ্ক অন্তর্ভুক্ত করে'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          প্রতিটি ফাইলের পরে অপেক্ষা করে'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             থ্রেড পুলের আকার (ডিফল্ট: nproc, সর্বনিম্ন 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           প্রতিটি কাজের এক লাইন FILE-এ যোগ করে'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        আনডু স্ক্রিপ্ট লেখে (ডিফল্ট: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            রঙিন আউটপুট বাধ্য করে (tty-তে স্বয়ংক্রিয় শনাক্ত)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         আর্কাইভ সাময়িক ডিরেক্টরিতে নিষ্কাশন করে বিষয়বস্তু সাজায়'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  নাম = আর্কাইভের ভেতরের মূল ডিরেক্টরি / একক ফাইল'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               ছবির জন্য <ক্যামেরা>/<YYYY-MM-DD> স্তর যোগ করে'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              কপি/সরানোর পরে লক্ষ্য থেকে EXIF/GPS মেটাডেটা সরায়'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            বিদ্যমান লক্ষ্য মুছে লেখে, নইলে অনন্য ~(N) নাম'
        else if S = 'Found %s file(s)' then Result := '%s টি ফাইল পাওয়া গেছে'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> আর্কাইভ মুছুন'
        else if S = 'Unknown option: %s' then Result := 'অজানা বিকল্প: %s'
        else if S = 'Invalid --mode: %s' then Result := 'অবৈধ --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash এর জন্য trash-put (trash-cli) ইনস্টল দরকার'
        else if S = 'Source directory not found: %s' then Result := 'সোর্স ডিরেক্টরি পাওয়া যায়নি: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'অসমর্থিত ভাষা: %s (--lang দেখুন)'
        else if S = 'Available languages (--lang=XX):' then Result := 'উপলব্ধ ভাষা (--lang=XX):'
        else if S = 'Summary' then Result := 'সারসংক্ষেপ'
        else if S = 'Copied : %s' then Result := 'কপি : %s'
        else if S = 'Moved  : %s' then Result := 'সরানো : %s'
        else if S = 'Removed: %s' then Result := 'মুছে ফেলা: %s'
        else if S = 'Trashed  : %s' then Result := 'ট্র্যাশ   : %s'
        else if S = 'Shredded : %s' then Result := 'শ্রেড    : %s'
        else if S = 'Extracted: %s' then Result := 'নিষ্কাশিত: %s'
        else if S = 'Preview: %s' then Result := 'প্রিভিউ: %s'
        else if S = 'Skipped: %s' then Result := 'এড়ানো: %s'
        else if S = 'Failed : %s' then Result := 'ব্যর্থ : %s'
        else if S = 'Undo script written: %s' then Result := 'আনডু স্ক্রিপ্ট লেখা হয়েছে: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'ব্যর্থ) %s - বের করা যায়নি (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'ব্যর্থ) ট্র্যাশ %s'
        else if S = 'FAILED) rm %s' then Result := 'ব্যর্থ) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'ব্যর্থ) ট্র্যাশ %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'ব্যর্থ) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'ব্যর্থ) স্থানান্তর %s'
        else if S = 'FAILED) copy %s' then Result := 'ব্যর্থ) কপি %s'
        else if S = 'MODES:' then Result := 'মোড:'
        else if S = 'STRUCTURE:' then Result := 'গন্তব্য ও নামকরণ:'
        else if S = 'FILTERS / SCOPE:' then Result := 'ফিল্টার ও প্রসেসিং:'
        else if S = 'ARCHIVES:' then Result := 'আর্কাইভ:'
        else if S = 'EXTRAS:' then Result := 'আউটপুট ও নিরাপত্তা:'
        else if S = 'LANGUAGES:' then Result := 'ভাষা:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          UI ভাষা (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             ভাষার তালিকা দেখান'
        else Result := S;
    end
    else if Lang = 'pt' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Uso: sort [OPÇÕES] [DIR...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Experimente sort --help para a lista completa de opções.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Organizador de arquivos Ejder - tradução FreePascal de Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      atalhos para --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  atalho para --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    atalhos para --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      níveis de diretório, separados por vírgula/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Apenas arquivos cujo tipo MIME contém VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Diretório base da árvore classificada (padrão: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Percorre os diretórios fornecidos em profundidade total'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Inclui arquivos e diretórios ocultos'
        else if S = '  --links            include symbolic links' then Result := '  --links              Inclui links simbólicos'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Espera após cada arquivo'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Tamanho do pool de threads (padrão: nproc, mín 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Acrescenta uma linha por ação a FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Escreve um script de desfazer (padrão: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Força saída colorida (autodetectada num tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Extrai compactados para um dir temporário e classifica o conteúdo'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Nome = dir principal / arquivo único dentro do compactado'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Adiciona níveis <Câmera>/<AAAA-MM-DD> para imagens'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Remove metadados EXIF/GPS dos destinos após copiar/mover'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Sobrescreve destinos existentes, senão nome único ~(N)'
        else if S = 'Found %s file(s)' then Result := 'Encontrado(s) %s arquivo(s)'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> apagar o arquivo'
        else if S = 'Unknown option: %s' then Result := 'Opção desconhecida: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode inválido: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash precisa de trash-put (trash-cli) instalado'
        else if S = 'Source directory not found: %s' then Result := 'Diretório de origem não encontrado: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Idioma não suportado: %s (veja --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Idiomas disponíveis (--lang=XX):'
        else if S = 'Summary' then Result := 'Resumo'
        else if S = 'Copied : %s' then Result := 'Copiados : %s'
        else if S = 'Moved  : %s' then Result := 'Movidos  : %s'
        else if S = 'Removed: %s' then Result := 'Removidos: %s'
        else if S = 'Trashed  : %s' then Result := 'Lixeira  : %s'
        else if S = 'Shredded : %s' then Result := 'Destruídos: %s'
        else if S = 'Extracted: %s' then Result := 'Extraídos: %s'
        else if S = 'Preview: %s' then Result := 'Prévia: %s'
        else if S = 'Skipped: %s' then Result := 'Ignorados: %s'
        else if S = 'Failed : %s' then Result := 'Falhas  : %s'
        else if S = 'Undo script written: %s' then Result := 'Script de desfazer escrito: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'FALHA) %s - não foi possível extrair (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'FALHA) lixeira %s'
        else if S = 'FAILED) rm %s' then Result := 'FALHA) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'FALHA) lixeira %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'FALHA) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'FALHA) mover %s'
        else if S = 'FAILED) copy %s' then Result := 'FALHA) copiar %s'
        else if S = 'MODES:' then Result := 'Modos:'
        else if S = 'STRUCTURE:' then Result := 'Destino e nomenclatura:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filtragem e processamento:'
        else if S = 'ARCHIVES:' then Result := 'Arquivos compactados:'
        else if S = 'EXTRAS:' then Result := 'Saída e segurança:'
        else if S = 'LANGUAGES:' then Result := 'Idiomas:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Idioma da interface (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Mostra a lista de idiomas'
        else Result := S;
    end
    else if Lang = 'ru' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Использование: sort [ОПЦИИ] [КАТАЛОГ...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Попробуйте sort --help для полного списка опций.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Организатор файлов Ejder - перевод Sort.sh v21 на FreePascal'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      сокращения для --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  сокращение для --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    сокращения для --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      уровни каталогов, через запятую/плюс:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Только файлы, чей MIME-тип содержит VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Базовый каталог дерева сортировки (по умолчанию: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Обходит указанные каталоги на всю глубину'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Включает скрытые файлы и каталоги'
        else if S = '  --links            include symbolic links' then Result := '  --links              Включает символические ссылки'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Пауза после каждого файла'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Размер пула потоков (по умолчанию: nproc, мин. 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Дописывает строку за каждое действие в FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Пишет скрипт отмены (по умолчанию: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Принудительно цветной вывод (автоопределение на tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Распаковывает архивы во временный каталог и сортирует содержимое'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Имя = главный каталог / единственный файл внутри архива'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Добавляет уровни <Камера>/<ГГГГ-ММ-ДД> для изображений'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Удаляет EXIF/GPS-метаданные целей после копирования/перемещения'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Перезаписывает существующие цели, иначе уникальное имя ~(N)'
        else if S = 'Found %s file(s)' then Result := 'Найдено файлов: %s'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> удалить архив'
        else if S = 'Unknown option: %s' then Result := 'Неизвестная опция: %s'
        else if S = 'Invalid --mode: %s' then Result := 'Недопустимый --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash требует установленный trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := 'Исходный каталог не найден: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Неподдерживаемый язык: %s (см. --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Доступные языки (--lang=XX):'
        else if S = 'Summary' then Result := 'Итоги'
        else if S = 'Copied : %s' then Result := 'Скопировано : %s'
        else if S = 'Moved  : %s' then Result := 'Перемещено : %s'
        else if S = 'Removed: %s' then Result := 'Удалено: %s'
        else if S = 'Trashed  : %s' then Result := 'В корзину: %s'
        else if S = 'Shredded : %s' then Result := 'Уничтожено: %s'
        else if S = 'Extracted: %s' then Result := 'Извлечено: %s'
        else if S = 'Preview: %s' then Result := 'Предпросмотр: %s'
        else if S = 'Skipped: %s' then Result := 'Пропущено: %s'
        else if S = 'Failed : %s' then Result := 'Сбоев : %s'
        else if S = 'Undo script written: %s' then Result := 'Скрипт отмены записан: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'СБОЙ) %s - не удалось распаковать (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'СБОЙ) корзина %s'
        else if S = 'FAILED) rm %s' then Result := 'СБОЙ) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'СБОЙ) корзина %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'СБОЙ) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'СБОЙ) перемещение %s'
        else if S = 'FAILED) copy %s' then Result := 'СБОЙ) копирование %s'
        else if S = 'MODES:' then Result := 'Режимы:'
        else if S = 'STRUCTURE:' then Result := 'Назначение и именование:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Фильтрация и обработка:'
        else if S = 'ARCHIVES:' then Result := 'Архивы:'
        else if S = 'EXTRAS:' then Result := 'Вывод и безопасность:'
        else if S = 'LANGUAGES:' then Result := 'Языки:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Язык интерфейса (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Показать список языков'
        else Result := S;
    end
    else if Lang = 'ur' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'استعمال: sort [اختیارات] [ڈائریکٹری...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'مکمل آپشن فہرست کے لیے sort --help آزمائیں۔'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder فائل منتظم - Sort.sh v21 کا FreePascal ترجمہ'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= کے شارٹ کٹس'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove کا شارٹ کٹ'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= کے شارٹ کٹس'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      ڈائریکٹری سطحیں، کاما/پلس سے جدا:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         صرف وہ فائلیں جن کی MIME قسم میں VALUE ہو'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         مرتب شدہ درخت کی بنیادی ڈائریکٹری (پہلے سے طے: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          دی گئی ڈائریکٹریوں کو مکمل گہرائی تک سیر کرتا ہے'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             چھپی ہوئی فائلیں اور ڈائریکٹریاں شامل کرتا ہے'
        else if S = '  --links            include symbolic links' then Result := '  --links              علامتی لنکس شامل کرتا ہے'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          ہر فائل کے بعد انتظار'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             تھریڈ پول کا سائز (پہلے سے طے: nproc، کم از کم 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           ہر عمل کی ایک سطر FILE میں شامل کرتا ہے'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        انڈو اسکرپٹ لکھتا ہے (پہلے سے طے: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            رنگین آؤٹ پٹ زبردستی (tty پر خودکار طور پر پہچانا جاتا ہے)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         آرکائیوز کو عارضی ڈائریکٹری میں کھول کر مواد مرتب کرتا ہے'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  نام = آرکائیو کے اندر مرکزی ڈائریکٹری / واحد فائل'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               تصاویر کے لیے <کیمرہ>/<YYYY-MM-DD> سطحوں کا اضافہ'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              copy/move کے بعد اہداف سے EXIF/GPS میٹا ڈیٹا ہٹاتا ہے'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            موجودہ اہداف پر لکھ دیتا ہے، ورنہ منفرد ~(N) نام'
        else if S = 'Found %s file(s)' then Result := '%s فائل(یں) ملیں'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> آرکائیو حذف کریں'
        else if S = 'Unknown option: %s' then Result := 'نامعلوم آپشن: %s'
        else if S = 'Invalid --mode: %s' then Result := 'غلط --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash کو trash-put (trash-cli) انسٹال درکار ہے'
        else if S = 'Source directory not found: %s' then Result := 'ماخذ ڈائریکٹری نہیں ملی: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'غیر معاون زبان: %s (دیکھیں --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'دستیاب زبانیں (--lang=XX):'
        else if S = 'Summary' then Result := 'خلاصہ'
        else if S = 'Copied : %s' then Result := 'کاپی  : %s'
        else if S = 'Moved  : %s' then Result := 'منتقل : %s'
        else if S = 'Removed: %s' then Result := 'ہٹایا : %s'
        else if S = 'Trashed  : %s' then Result := 'ٹراش   : %s'
        else if S = 'Shredded : %s' then Result := 'شریڈ   : %s'
        else if S = 'Extracted: %s' then Result := 'ان زیپ: %s'
        else if S = 'Preview: %s' then Result := 'پیش نظارہ: %s'
        else if S = 'Skipped: %s' then Result := 'چھوڑا : %s'
        else if S = 'Failed : %s' then Result := 'ناکام : %s'
        else if S = 'Undo script written: %s' then Result := 'انڈو اسکرپٹ لکھی گئی: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'ناکام) %s - نکال نہیں سکا (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'ناکام) ٹراش %s'
        else if S = 'FAILED) rm %s' then Result := 'ناکام) حذف %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'ناکام) ٹراش %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'ناکام) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'ناکام) منتقلی %s'
        else if S = 'FAILED) copy %s' then Result := 'ناکام) کاپی %s'
        else if S = 'MODES:' then Result := 'موڈ:'
        else if S = 'STRUCTURE:' then Result := 'ہدف اور نامگذاری:'
        else if S = 'FILTERS / SCOPE:' then Result := 'فلٹرنگ اور پروسیسنگ:'
        else if S = 'ARCHIVES:' then Result := 'آرکائیوز:'
        else if S = 'EXTRAS:' then Result := 'آؤٹ پٹ اور حفاظت:'
        else if S = 'LANGUAGES:' then Result := 'زبانیں:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          انٹرفیس کی زبان (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             زبانوں کی فہرست دکھائیں'
        else Result := S;
    end
    else if Lang = 'id' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Penggunaan: sort [OPSI] [DIR...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Coba sort --help untuk daftar opsi lengkap.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Penyusun berkas Ejder - terjemahan FreePascal dari Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      pintasan untuk --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  pintasan untuk --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    pintasan untuk --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      tingkat direktori, dipisah koma/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Hanya berkas dengan tipe MIME yang memuat VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Direktori dasar pohon tersusun (bawaan: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Menelusuri direktori yang diberikan sampai kedalaman penuh'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Menyertakan berkas dan direktori tersembunyi'
        else if S = '  --links            include symbolic links' then Result := '  --links              Menyertakan tautan simbolik'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Menunggu setelah setiap berkas'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Ukuran pool thread (bawaan: nproc, min 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Menambah satu baris per aksi ke FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Menulis skrip undo (bawaan: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Memaksa keluaran berwarna (terdeteksi otomatis pada tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Mengekstrak arsip ke dir sementara dan menyusun isinya'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Nama = direktori utama / berkas tunggal di dalam arsip'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Menambah tingkat <Kamera>/<YYYY-MM-DD> untuk gambar'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Melepas metadata EXIF/GPS dari target setelah copy/move'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Menimpa target yang ada, jika tidak nama ~(N) unik'
        else if S = 'Found %s file(s)' then Result := 'Ditemukan %s berkas'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> hapus arsip'
        else if S = 'Unknown option: %s' then Result := 'Opsi tidak dikenal: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode tidak valid: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash membutuhkan trash-put (trash-cli) terpasang'
        else if S = 'Source directory not found: %s' then Result := 'Direktori sumber tidak ditemukan: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Bahasa tidak didukung: %s (lihat --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Bahasa yang tersedia (--lang=XX):'
        else if S = 'Summary' then Result := 'Ringkasan'
        else if S = 'Copied : %s' then Result := 'Disalin  : %s'
        else if S = 'Moved  : %s' then Result := 'Dipindah : %s'
        else if S = 'Removed: %s' then Result := 'Dihapus : %s'
        else if S = 'Trashed  : %s' then Result := 'Sampah  : %s'
        else if S = 'Shredded : %s' then Result := 'Dihancurkan: %s'
        else if S = 'Extracted: %s' then Result := 'Diekstrak: %s'
        else if S = 'Preview: %s' then Result := 'Pratinjau: %s'
        else if S = 'Skipped: %s' then Result := 'Dilewati: %s'
        else if S = 'Failed : %s' then Result := 'Gagal    : %s'
        else if S = 'Undo script written: %s' then Result := 'Skrip undo ditulis: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'GAGAL) %s - tidak dapat mengekstrak (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'GAGAL) sampah %s'
        else if S = 'FAILED) rm %s' then Result := 'GAGAL) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'GAGAL) sampah %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'GAGAL) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'GAGAL) pindah %s'
        else if S = 'FAILED) copy %s' then Result := 'GAGAL) salin %s'
        else if S = 'MODES:' then Result := 'Mode:'
        else if S = 'STRUCTURE:' then Result := 'Tujuan dan penamaan:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Penyaringan dan pemrosesan:'
        else if S = 'ARCHIVES:' then Result := 'Arsip:'
        else if S = 'EXTRAS:' then Result := 'Keluaran dan keamanan:'
        else if S = 'LANGUAGES:' then Result := 'Bahasa:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Bahasa antarmuka (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Cetak daftar bahasa'
        else Result := S;
    end
    else if Lang = 'de' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Aufruf: sort [OPTIONEN] [VERZ...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Versuchen Sie sort --help für die vollständige Optionsliste.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder Datei-Organisator - FreePascal-Übersetzung von Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      Kurzformen für --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  Kurzform für --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    Kurzformen für --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      Verzeichnisebenen, getrennt durch Komma/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Nur Dateien, deren MIME-Typ VALUE enthält'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Basisverzeichnis des sortierten Baums (Standard: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Durchläuft angegebene Verzeichnisse bis in volle Tiefe'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Schließt versteckte Dateien und Verzeichnisse ein'
        else if S = '  --links            include symbolic links' then Result := '  --links              Schließt symbolische Links ein'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Wartet nach jeder Datei'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Thread-Pool-Größe (Standard: nproc, min. 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Hängt eine Zeile pro Aktion an FILE an'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Schreibt ein Undo-Skript (Standard: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Erzwingt farbige Ausgabe (auf einem tty automatisch erkannt)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Entpackt Archive in ein Temp-Verzeichnis und sortiert die Inhalte'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Name = Hauptverzeichnis / einzelne Datei im Archiv'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Ergänzt <Kamera>/<YYYY-MM-DD>-Ebenen für Bilder'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Entfernt EXIF/GPS-Metadaten aus Zielen nach copy/move'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Überschreibt vorhandene Ziele, sonst eindeutiger ~(N)-Name'
        else if S = 'Found %s file(s)' then Result := '%s Datei(en) gefunden'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> Archiv löschen'
        else if S = 'Unknown option: %s' then Result := 'Unbekannte Option: %s'
        else if S = 'Invalid --mode: %s' then Result := 'Ungültiger --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash benötigt installiertes trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := 'Quellverzeichnis nicht gefunden: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Nicht unterstützte Sprache: %s (siehe --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Verfügbare Sprachen (--lang=XX):'
        else if S = 'Summary' then Result := 'Zusammenfassung'
        else if S = 'Copied : %s' then Result := 'Kopiert    : %s'
        else if S = 'Moved  : %s' then Result := 'Verschoben : %s'
        else if S = 'Removed: %s' then Result := 'Entfernt   : %s'
        else if S = 'Trashed  : %s' then Result := 'Papierkorb: %s'
        else if S = 'Shredded : %s' then Result := 'Geschreddert: %s'
        else if S = 'Extracted: %s' then Result := 'Entpackt: %s'
        else if S = 'Preview: %s' then Result := 'Vorschau: %s'
        else if S = 'Skipped: %s' then Result := 'Übersprungen: %s'
        else if S = 'Failed : %s' then Result := 'Fehlgeschlagen: %s'
        else if S = 'Undo script written: %s' then Result := 'Undo-Skript geschrieben: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'FEHLER) %s - Entpacken nicht möglich (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'FEHLER) Papierkorb %s'
        else if S = 'FAILED) rm %s' then Result := 'FEHLER) rm %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'FEHLER) Papierkorb %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'FEHLER) mkdir %s'
        else if S = 'FAILED) move %s' then Result := 'FEHLER) verschieben %s'
        else if S = 'FAILED) copy %s' then Result := 'FEHLER) kopieren %s'
        else if S = 'MODES:' then Result := 'Modi:'
        else if S = 'STRUCTURE:' then Result := 'Ziel und Benennung:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filterung und Verarbeitung:'
        else if S = 'ARCHIVES:' then Result := 'Archive:'
        else if S = 'EXTRAS:' then Result := 'Ausgabe und Sicherheit:'
        else if S = 'LANGUAGES:' then Result := 'Sprachen:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Oberflächensprache (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Sprachliste anzeigen'
        else Result := S;
    end
    else if Lang = 'ja' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := '使い方: sort [オプション] [ディレクトリ...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := '完全なオプション一覧は sort --help を試してください。'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder ファイル整理ツール - Sort.sh v21 の FreePascal 翻訳'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= の短縮形'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove の短縮形'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= の短縮形'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      ディレクトリ階層、カンマ/+ で区切る:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         MIME タイプに VALUE を含むファイルのみ'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         整理ツリーの基準ディレクトリ (既定: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          指定ディレクトリを最深部までたどります'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             隠しファイルと隠しディレクトリを含めます'
        else if S = '  --links            include symbolic links' then Result := '  --links              シンボリックリンクを含めます'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          各ファイルの後に待機します'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             スレッドプールのサイズ (既定: nproc、最小 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           操作ごとに 1 行を FILE に追記します'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        取り消しスクリプトを書き出します (既定: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            カラー出力を強制します (tty では自動判定)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         アーカイブを一時ディレクトリへ展開し中身を整理します'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  名前 = アーカイブ内の主ディレクトリ / 単一ファイル'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               画像に <カメラ>/<YYYY-MM-DD> 階層を追加します'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              copy/move 後にターゲットから EXIF/GPS メタデータを除去します'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            既存のターゲットを上書き、なければ一意な ~(N) 名'
        else if S = 'Found %s file(s)' then Result := '%s 個のファイルが見つかりました'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> アーカイブを削除'
        else if S = 'Unknown option: %s' then Result := '不明なオプション: %s'
        else if S = 'Invalid --mode: %s' then Result := '無効な --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash には trash-put (trash-cli) のインストールが必要です'
        else if S = 'Source directory not found: %s' then Result := 'ソースディレクトリが見つかりません: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := '未対応の言語: %s (--lang を参照)'
        else if S = 'Available languages (--lang=XX):' then Result := '利用可能な言語 (--lang=XX):'
        else if S = 'Summary' then Result := '概要'
        else if S = 'Copied : %s' then Result := 'コピー : %s'
        else if S = 'Moved  : %s' then Result := '移動   : %s'
        else if S = 'Removed: %s' then Result := '削除   : %s'
        else if S = 'Trashed  : %s' then Result := 'ゴミ箱  : %s'
        else if S = 'Shredded : %s' then Result := '完全消去: %s'
        else if S = 'Extracted: %s' then Result := '展開   : %s'
        else if S = 'Preview: %s' then Result := 'プレビュー: %s'
        else if S = 'Skipped: %s' then Result := '除外   : %s'
        else if S = 'Failed : %s' then Result := '失敗   : %s'
        else if S = 'Undo script written: %s' then Result := '取り消しスクリプトを書き出しました: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := '失敗) %s - 展開できませんでした (rc %s)'
        else if S = 'FAILED) trash %s' then Result := '失敗) ゴミ箱 %s'
        else if S = 'FAILED) rm %s' then Result := '失敗) 削除 %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := '失敗) ゴミ箱 %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := '失敗) ディレクトリ作成 %s'
        else if S = 'FAILED) move %s' then Result := '失敗) 移動 %s'
        else if S = 'FAILED) copy %s' then Result := '失敗) コピー %s'
        else if S = 'MODES:' then Result := 'モード:'
        else if S = 'STRUCTURE:' then Result := '出力先と命名:'
        else if S = 'FILTERS / SCOPE:' then Result := 'フィルタと処理:'
        else if S = 'ARCHIVES:' then Result := 'アーカイブ:'
        else if S = 'EXTRAS:' then Result := '出力と安全:'
        else if S = 'LANGUAGES:' then Result := '言語:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          表示言語 (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             言語一覧を表示'
        else Result := S;
    end
    else if Lang = 'tr' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Kullanım: sort [seçenekler] [dizin...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Tüm seçenek listesi için sort --help deneyin.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder Dosya Düzenleyici - Sort.sh v21 FreePascal çevirisi'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= kısayolu'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove kısayolu'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= kısayolu'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      Dizin seviyeleri, virgül/+ ile ayrılmış:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Yalnızca MIME türü VALUE içeren dosyalar'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Sıralı ağacın taban dizini (varsayılan: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Verilen dizinleri en derine kadar gezer'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Gizli dosya ve dizinleri kapsar'
        else if S = '  --links            include symbolic links' then Result := '  --links              Simgesel bağlantıları kapsar'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Her dosyadan sonra bekler'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             İş parçacığı havuzu boyutu (varsayılan: nproc, en az 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Her işlem için bir satırı FILE sonuna ekler'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Geri alma betiği yazar (varsayılan: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Renkli çıktıyı zorlar (tty üzerinde otomatik algılanır)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Arşivleri geçici dizine açar ve içeriğini düzenler'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Ad = arşiv içindeki ana dizin / tek dosya'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Görüntüler için <Kamera>/<YYYY-MM-DD> düzeyleri ekler'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              copy/move sonrası hedeflerden EXIF/GPS meta verisini sıyırır'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Var olan hedeflerin üzerine yazar, yoksa özgün ~(N) ad'
        else if S = 'Found %s file(s)' then Result := '%s dosya bulundu'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> arşivi sil'
        else if S = 'Unknown option: %s' then Result := 'Bilinmeyen seçenek: %s'
        else if S = 'Invalid --mode: %s' then Result := 'Geçersiz --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash için trash-put (trash-cli) gerekir'
        else if S = 'Source directory not found: %s' then Result := 'Kaynak dizin bulunamadı: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Desteklenmeyen dil: %s (--lang bakın)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Kullanılabilir diller (--lang=XX):'
        else if S = 'Summary' then Result := 'Özet'
        else if S = 'Copied : %s' then Result := 'Kopyalandı : %s'
        else if S = 'Moved  : %s' then Result := 'Taşındı   : %s'
        else if S = 'Removed: %s' then Result := 'Kaldırıldı: %s'
        else if S = 'Trashed  : %s' then Result := 'Çöp     : %s'
        else if S = 'Shredded : %s' then Result := 'Parçalandı: %s'
        else if S = 'Extracted: %s' then Result := 'Açıldı: %s'
        else if S = 'Preview: %s' then Result := 'Önizleme: %s'
        else if S = 'Skipped: %s' then Result := 'Atlandı: %s'
        else if S = 'Failed : %s' then Result := 'Başarısız : %s'
        else if S = 'Undo script written: %s' then Result := 'Geri alma betiği yazıldı: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'HATA) %s - ayıklanamadı (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'HATA) çöp %s'
        else if S = 'FAILED) rm %s' then Result := 'HATA) silme %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'HATA) çöp %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'HATA) dizin oluşturma %s'
        else if S = 'FAILED) move %s' then Result := 'HATA) taşıma %s'
        else if S = 'FAILED) copy %s' then Result := 'HATA) kopyalama %s'
        else if S = 'MODES:' then Result := 'Modlar:'
        else if S = 'STRUCTURE:' then Result := 'Hedef ve adlandırma:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filtreleme ve işleme:'
        else if S = 'ARCHIVES:' then Result := 'Arşivler:'
        else if S = 'EXTRAS:' then Result := 'Çıktı ve güvenlik:'
        else if S = 'LANGUAGES:' then Result := 'Diller:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Arayüz dili (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Dil listesini yazdır'
        else Result := S;
    end
    else if Lang = 'ko' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := '사용법: sort [옵션] [디렉터리...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := '전체 옵션 목록은 sort --help를 실행해 보십시오.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder 파일 정리 도구 - Sort.sh v21 FreePascal 번역'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      --mode= 의 단축형'
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  --mode=remove 의 단축형'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    --mode= 의 단축형'
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      디렉터리 단계, 쉼표/+로 구분:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         MIME 타입에 VALUE가 포함된 파일만'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         정리 트리의 기준 디렉터리 (기본값: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          지정한 디렉터리를 끝까지 탐색합니다'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             숨김 파일과 숨김 디렉터리를 포함합니다'
        else if S = '  --links            include symbolic links' then Result := '  --links              심볼릭 링크를 포함합니다'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          각 파일 후에 대기합니다'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             스레드 풀 크기 (기본값: nproc, 최소 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           작업마다 한 줄씩 FILE에 추가합니다'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        되돌리기 스크립트를 작성합니다 (기본값: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            색상 출력을 강제합니다 (tty에서 자동 감지)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         아카이브를 임시 디렉터리에 풀고 내용을 정리합니다'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  이름 = 아카이브 안의 기본 디렉터리 / 단일 파일'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               이미지에 <카메라>/<YYYY-MM-DD> 단계를 추가합니다'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              copy/move 후 대상에서 EXIF/GPS 메타데이터를 제거합니다'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            기존 대상을 덮어쓰고, 없으면 고유한 ~(N) 이름'
        else if S = 'Found %s file(s)' then Result := '%s개의 파일을 찾았습니다'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> 아카이브 삭제'
        else if S = 'Unknown option: %s' then Result := '알 수 없는 옵션: %s'
        else if S = 'Invalid --mode: %s' then Result := '잘못된 --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash 에는 trash-put (trash-cli)이 필요합니다'
        else if S = 'Source directory not found: %s' then Result := '소스 디렉터리를 찾을 수 없습니다: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := '지원하지 않는 언어: %s (--lang 참조)'
        else if S = 'Available languages (--lang=XX):' then Result := '사용 가능한 언어 (--lang=XX):'
        else if S = 'Summary' then Result := '요약'
        else if S = 'Copied : %s' then Result := '복사됨 : %s'
        else if S = 'Moved  : %s' then Result := '이동됨 : %s'
        else if S = 'Removed: %s' then Result := '제거됨 : %s'
        else if S = 'Trashed  : %s' then Result := '휴지통 : %s'
        else if S = 'Shredded : %s' then Result := '완전 삭제: %s'
        else if S = 'Extracted: %s' then Result := '해제됨 : %s'
        else if S = 'Preview: %s' then Result := '미리보기: %s'
        else if S = 'Skipped: %s' then Result := '건너뜀 : %s'
        else if S = 'Failed : %s' then Result := '실패   : %s'
        else if S = 'Undo script written: %s' then Result := '되돌리기 스크립트를 저장했습니다: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := '실패) %s - 압축 해제 불가 (rc %s)'
        else if S = 'FAILED) trash %s' then Result := '실패) 휴지통 %s'
        else if S = 'FAILED) rm %s' then Result := '실패) 삭제 %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := '실패) 휴지통 %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := '실패) 디렉터리 생성 %s'
        else if S = 'FAILED) move %s' then Result := '실패) 이동 %s'
        else if S = 'FAILED) copy %s' then Result := '실패) 복사 %s'
        else if S = 'MODES:' then Result := '모드:'
        else if S = 'STRUCTURE:' then Result := '대상과 이름짓기:'
        else if S = 'FILTERS / SCOPE:' then Result := '필터와 처리:'
        else if S = 'ARCHIVES:' then Result := '아카이브:'
        else if S = 'EXTRAS:' then Result := '출력과 안전:'
        else if S = 'LANGUAGES:' then Result := '언어:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          인터페이스 언어 (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             언어 목록 출력'
        else Result := S;
    end
    else if Lang = 'vi' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Cách dùng: sort [tùy chọn] [thư mục...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Hãy thử sort --help để xem danh sách tùy chọn đầy đủ.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder công cụ sắp xếp tệp - bản dịch FreePascal của Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      viết tắt của --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  viết tắt của --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    viết tắt của --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      Cấp thư mục, phân tách bằng dấu phẩy/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Chỉ tệp có kiểu MIME chứa VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Thư mục gốc của cây sắp xếp (mặc định: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Duyệt các thư mục cho trước đến tận cùng'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Bao gồm tệp và thư mục ẩn'
        else if S = '  --links            include symbolic links' then Result := '  --links              Bao gồm liên kết tượng trưng'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Chờ sau mỗi tệp'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Kích thước nhóm luồng (mặc định: nproc, tối thiểu 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Nối một dòng mỗi thao tác vào FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Viết script hoàn tác (mặc định: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Ép đầu ra có màu (tự dò trên tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Giải nén kho vào thư mục tạm rồi sắp xếp nội dung'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Tên = thư mục chính / tệp đơn trong kho'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Thêm tầng <Máy ảnh>/<YYYY-MM-DD> cho ảnh'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Gỡ metadata EXIF/GPS khỏi đích sau copy/move'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Ghi đè đích đã có, nếu không tên ~(N) duy nhất'
        else if S = 'Found %s file(s)' then Result := 'Đã tìm thấy %s tệp'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> xóa kho'
        else if S = 'Unknown option: %s' then Result := 'Tùy chọn không rõ: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode không hợp lệ: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash cần trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := 'Không tìm thấy thư mục nguồn: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Ngôn ngữ không được hỗ trợ: %s (xem --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Các ngôn ngữ có sẵn (--lang=XX):'
        else if S = 'Summary' then Result := 'Tóm tắt'
        else if S = 'Copied : %s' then Result := 'Đã sao chép : %s'
        else if S = 'Moved  : %s' then Result := 'Đã chuyển   : %s'
        else if S = 'Removed: %s' then Result := 'Đã gỡ bỏ    : %s'
        else if S = 'Trashed  : %s' then Result := 'Thùng rác: %s'
        else if S = 'Shredded : %s' then Result := 'Xóa an toàn: %s'
        else if S = 'Extracted: %s' then Result := 'Đã giải nén: %s'
        else if S = 'Preview: %s' then Result := 'Xem trước: %s'
        else if S = 'Skipped: %s' then Result := 'Đã bỏ qua: %s'
        else if S = 'Failed : %s' then Result := 'Thất bại : %s'
        else if S = 'Undo script written: %s' then Result := 'Đã ghi tập lệnh hoàn tác: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'LỖI) %s - không thể giải nén (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'LỖI) bỏ vào thùng rác %s'
        else if S = 'FAILED) rm %s' then Result := 'LỖI) xóa %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'LỖI) bỏ vào thùng rác %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'LỖI) tạo thư mục %s'
        else if S = 'FAILED) move %s' then Result := 'LỖI) di chuyển %s'
        else if S = 'FAILED) copy %s' then Result := 'LỖI) sao chép %s'
        else if S = 'MODES:' then Result := 'Chế độ:'
        else if S = 'STRUCTURE:' then Result := 'Đích và đặt tên:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Lọc và xử lý:'
        else if S = 'ARCHIVES:' then Result := 'Kho lưu trữ:'
        else if S = 'EXTRAS:' then Result := 'Đầu ra và an toàn:'
        else if S = 'LANGUAGES:' then Result := 'Ngôn ngữ:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Ngôn ngữ giao diện (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             In danh sách ngôn ngữ'
        else Result := S;
    end
    else if Lang = 'it' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Uso: sort [opzioni] [directory...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Prova sort --help per l’elenco completo delle opzioni.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder strumento di ordinamento file - traduzione FreePascal di Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      scorciatoia per --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  scorciatoia per --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    scorciatoia per --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      Livelli di directory, separati da virgola/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Solo file il cui tipo MIME contiene VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Directory base dell''albero ordinato (predefinito: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Attraversa le directory fornite fino in profondità'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Include file e directory nascosti'
        else if S = '  --links            include symbolic links' then Result := '  --links              Include collegamenti simbolici'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Attende dopo ogni file'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Dimensione del pool di thread (predefinito: nproc, min 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Aggiunge una riga per azione a FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Scrive uno script di annullamento (predefinito: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Forza l''output colorato (rilevato automaticamente su un tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Estrae gli archivi in una dir temporanea e ordina il contenuto'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Nome = directory principale / file singolo dentro l''archivio'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Aggiunge livelli <Fotocamera>/<YYYY-MM-DD> per le immagini'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Rimuove i metadati EXIF/GPS dalle destinazioni dopo copy/move'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Sovrascrive le destinazioni esistenti, altrimenti nome ~(N) unico'
        else if S = 'Found %s file(s)' then Result := 'Trovati %s file'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> elimina l''archivio'
        else if S = 'Unknown option: %s' then Result := 'Opzione sconosciuta: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode non valido: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash richiede trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := 'Directory di origine non trovata: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Lingua non supportata: %s (vedi --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Lingue disponibili (--lang=XX):'
        else if S = 'Summary' then Result := 'Riepilogo'
        else if S = 'Copied : %s' then Result := 'Copiati  : %s'
        else if S = 'Moved  : %s' then Result := 'Spostati : %s'
        else if S = 'Removed: %s' then Result := 'Rimossi  : %s'
        else if S = 'Trashed  : %s' then Result := 'Cestinati: %s'
        else if S = 'Shredded : %s' then Result := 'Distrutti : %s'
        else if S = 'Extracted: %s' then Result := 'Estratti : %s'
        else if S = 'Preview: %s' then Result := 'Anteprima: %s'
        else if S = 'Skipped: %s' then Result := 'Saltati  : %s'
        else if S = 'Failed : %s' then Result := 'Falliti  : %s'
        else if S = 'Undo script written: %s' then Result := 'Script di annullamento scritto: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'ERRORE) %s - estrazione non riuscita (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'ERRORE) cestino %s'
        else if S = 'FAILED) rm %s' then Result := 'ERRORE) rimozione %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'ERRORE) cestino %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'ERRORE) creazione directory %s'
        else if S = 'FAILED) move %s' then Result := 'ERRORE) spostamento %s'
        else if S = 'FAILED) copy %s' then Result := 'ERRORE) copia %s'
        else if S = 'MODES:' then Result := 'Modalità:'
        else if S = 'STRUCTURE:' then Result := 'Destinazione e denominazione:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filtraggio ed elaborazione:'
        else if S = 'ARCHIVES:' then Result := 'Archivi:'
        else if S = 'EXTRAS:' then Result := 'Output e sicurezza:'
        else if S = 'LANGUAGES:' then Result := 'Lingue:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Lingua dell''interfaccia (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Stampa l''elenco delle lingue'
        else Result := S;
    end
    else if Lang = 'pl' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Użycie: sort [opcje] [katalogi...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Spróbuj sort --help, aby zobaczyć pełną listę opcji.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder narzędzie do porządkowania plików - tłumaczenie FreePascal Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      skrót od --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  skrót od --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    skrót od --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      Poziomy katalogów, oddzielone przecinkiem/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Tylko pliki, których typ MIME zawiera VALUE'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Katalog bazowy drzewa (domyślnie: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Przechodzi przez podane katalogi do pełnej głębokości'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Uwzględnia ukryte pliki i katalogi'
        else if S = '  --links            include symbolic links' then Result := '  --links              Uwzględnia dowiązania symboliczne'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Czeka po każdym pliku'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Rozmiar puli wątków (domyślnie: nproc, min. 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Dopisuje jedną linię na akcję do FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Pisze skrypt cofania (domyślnie: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Wymusza kolorowe wyjście (automatycznie wykrywane na tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Rozpakowuje archiwa do katalogu tymczasowego i porządkuje zawartość'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Nazwa = główny katalog / pojedynczy plik wewnątrz archiwum'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Dodaje poziomy <Aparat>/<YYYY-MM-DD> dla obrazów'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Usuwa metadane EXIF/GPS z celów po copy/move'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Nadpisuje istniejące cele, w przeciwnym razie unikalna nazwa ~(N)'
        else if S = 'Found %s file(s)' then Result := 'Znaleziono plików: %s'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> usuń archiwum'
        else if S = 'Unknown option: %s' then Result := 'Nieznana opcja: %s'
        else if S = 'Invalid --mode: %s' then Result := 'Nieprawidłowy --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash wymaga trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := 'Nie znaleziono katalogu źródłowego: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Nieobsługiwany język: %s (zobacz --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Dostępne języki (--lang=XX):'
        else if S = 'Summary' then Result := 'Podsumowanie'
        else if S = 'Copied : %s' then Result := 'Skopiowano  : %s'
        else if S = 'Moved  : %s' then Result := 'Przeniesiono: %s'
        else if S = 'Removed: %s' then Result := 'Usunięto    : %s'
        else if S = 'Trashed  : %s' then Result := 'Do kosza : %s'
        else if S = 'Shredded : %s' then Result := 'Zniszczone: %s'
        else if S = 'Extracted: %s' then Result := 'Rozpakowano: %s'
        else if S = 'Preview: %s' then Result := 'Podgląd: %s'
        else if S = 'Skipped: %s' then Result := 'Pominięto: %s'
        else if S = 'Failed : %s' then Result := 'Nieudane    : %s'
        else if S = 'Undo script written: %s' then Result := 'Zapisano skrypt cofania: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'BŁĄD) %s - nie można rozpakować (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'BŁĄD) kosz %s'
        else if S = 'FAILED) rm %s' then Result := 'BŁĄD) usuwanie %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'BŁĄD) kosz %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'BŁĄD) tworzenie katalogu %s'
        else if S = 'FAILED) move %s' then Result := 'BŁĄD) przenoszenie %s'
        else if S = 'FAILED) copy %s' then Result := 'BŁĄD) kopiowanie %s'
        else if S = 'MODES:' then Result := 'Tryby:'
        else if S = 'STRUCTURE:' then Result := 'Cel i nazywanie:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filtrowanie i przetwarzanie:'
        else if S = 'ARCHIVES:' then Result := 'Archiwa:'
        else if S = 'EXTRAS:' then Result := 'Wyjście i bezpieczeństwo:'
        else if S = 'LANGUAGES:' then Result := 'Języki:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Język interfejsu (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Wyświetl listę języków'
        else Result := S;
    end
    else if Lang = 'nl' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'Gebruik: sort [opties] [mappen...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'Probeer sort --help voor de volledige optielijst.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'Ejder bestandsorganisatie-tool - FreePascal-vertaling van Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      sneltoets voor --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  sneltoets voor --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    sneltoets voor --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      Mapniveaus, gescheiden door komma/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         Alleen bestanden waarvan het MIME-type VALUE bevat'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         Basismap van de gesorteerde boom (standaard: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          Doorloopt opgegeven mappen tot volledige diepte'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             Omvat verborgen bestanden en mappen'
        else if S = '  --links            include symbolic links' then Result := '  --links              Omvat symbolische koppelingen'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          Wacht na elk bestand'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             Thread-poolgrootte (standaard: nproc, min. 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           Voegt één regel per actie toe aan FILE'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        Schrijft een undo-script (standaard: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            Forceert gekleurde uitvoer (automatisch gedetecteerd op een tty)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         Pakt archieven uit in een tijdelijke map en sorteert de inhoud'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  Naam = hoofdmap / enkel bestand in het archief'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               Voegt <Camera>/<YYYY-MM-DD>-niveaus toe voor afbeeldingen'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              Verwijdert EXIF/GPS-metadata van doelen na copy/move'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            Overschrijft bestaande doelen, anders unieke ~(N)-naam'
        else if S = 'Found %s file(s)' then Result := '%s bestanden gevonden'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> archief verwijderen'
        else if S = 'Unknown option: %s' then Result := 'Onbekende optie: %s'
        else if S = 'Invalid --mode: %s' then Result := 'Ongeldige --mode: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash vereist trash-put (trash-cli)'
        else if S = 'Source directory not found: %s' then Result := 'Bronmap niet gevonden: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'Niet-ondersteunde taal: %s (zie --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'Beschikbare talen (--lang=XX):'
        else if S = 'Summary' then Result := 'Samenvatting'
        else if S = 'Copied : %s' then Result := 'Gekopieerd : %s'
        else if S = 'Moved  : %s' then Result := 'Verplaatst : %s'
        else if S = 'Removed: %s' then Result := 'Verwijderd : %s'
        else if S = 'Trashed  : %s' then Result := 'Prullenbak: %s'
        else if S = 'Shredded : %s' then Result := 'Versnipperd: %s'
        else if S = 'Extracted: %s' then Result := 'Uitgepakt: %s'
        else if S = 'Preview: %s' then Result := 'Voorbeeld: %s'
        else if S = 'Skipped: %s' then Result := 'Overgeslagen: %s'
        else if S = 'Failed : %s' then Result := 'Mislukt  : %s'
        else if S = 'Undo script written: %s' then Result := 'Herstelscript geschreven: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'FOUT) %s - uitpakken mislukt (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'FOUT) prullenbak %s'
        else if S = 'FAILED) rm %s' then Result := 'FOUT) verwijderen %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'FOUT) prullenbak %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'FOUT) map aanmaken %s'
        else if S = 'FAILED) move %s' then Result := 'FOUT) verplaatsen %s'
        else if S = 'FAILED) copy %s' then Result := 'FOUT) kopiëren %s'
        else if S = 'MODES:' then Result := 'Modi:'
        else if S = 'STRUCTURE:' then Result := 'Doel en naamgeving:'
        else if S = 'FILTERS / SCOPE:' then Result := 'Filteren en verwerken:'
        else if S = 'ARCHIVES:' then Result := 'Archieven:'
        else if S = 'EXTRAS:' then Result := 'Uitvoer en veiligheid:'
        else if S = 'LANGUAGES:' then Result := 'Talen:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          Interfacetaal (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             Toon de taallijst'
        else Result := S;
    end
    else if Lang = 'fa' then
    begin
        if S = 'Usage: sort [OPTIONS] [DIR...]' then Result := 'روش استفاده: sort [گزینه‌ها] [پوشه‌ها...]'
        else if S = 'Try ''sort --help'' for the full option list.' then Result := 'برای فهرست کامل گزینه‌ها «sort --help» را امتحان کنید.'
        else if S = 'Ejder file organizer - FreePascal translation of Sort.sh v21' then Result := 'ابزار مرتب‌سازی فایل Ejder - ترجمه FreePascal از Sort.sh v21'
        else if S = '  --copy --move      shortcuts for --mode=' then Result := '  --copy --move      شکل کوتاه --mode='
        else if S = '  --remove --delete  shortcut for --mode=remove' then Result := '  --remove --delete  شکل کوتاه --mode=remove'
        else if S = '  --trash --shred    shortcuts for --mode=' then Result := '  --trash --shred    شکل کوتاه --mode='
        else if S = '  --dirs=LEVELS      directory levels, comma/plus separated:' then Result := '  --dirs=LEVELS      سطوح پوشه، جدا شده با ویرگول/+:'
        else if S = '  --type=VALUE       only files whose MIME contains VALUE' then Result := '  --type=VALUE         فقط فایل‌هایی که نوع MIME شامل VALUE باشد'
        else if S = '  --target=DIR       root for the new tree (default: current directory)' then Result := '  --target=DIR         پوشه پایه درخت مرتب (پیش‌فرض: .)'
        else if S = '  --recursive        walk subdirectories (default: non-recursive)' then Result := '  --recursive          پوشه‌های داده‌شده را تا عمق کامل می‌پیماید'
        else if S = '  --hidden           include hidden files' then Result := '  --hidden             فایل‌ها و پوشه‌های پنهان را شامل می‌شود'
        else if S = '  --links            include symbolic links' then Result := '  --links              پیوندهای نمادین را شامل می‌شود'
        else if S = '  --pause=SEC        sleep between files' then Result := '  --pause=SEC          بعد از هر فایل منتظر می‌ماند'
        else if S = '  --jobs=N           parallel workers (default: 1)' then Result := '  --jobs=N             اندازه استخر نخ‌ها (پیش‌فرض: nproc، حداقل 1)'
        else if S = '  --log=FILE         append an action log' then Result := '  --log=FILE           هر عمل یک خط به FILE می‌افزاید'
        else if S = '  --undo[=FILE]      write an inverse shell script' then Result := '  --undo[=FILE]        اسکریپت بازگردانی می‌نویسد (پیش‌فرض: sort_undo_<time>.sh)'
        else if S = '  --colored          ANSI-colored output' then Result := '  --colored            خروجی رنگی را اجباری می‌کند (روی tty خودکار تشخیص داده می‌شود)'
        else if S = '  --decompress       extract archives first and process the contents' then Result := '  --decompress         آرشیوها را در پوشه موقت باز و محتوایشان را مرتب می‌کند'
        else if S = '  --rename=compressed  rename archive to its main inner directory/file' then Result := '  --rename=compressed  نام = پوشه اصلی / تک‌فایل درون آرشیو'
        else if S = '  --exif             add <Camera>/<Date> levels (needs exiftool)' then Result := '  --exif               برای تصاویر سطح‌های <دوربین>/<YYYY-MM-DD> می‌افزاید'
        else if S = '  --strip            strip EXIF from processed files (needs exiftool)' then Result := '  --strip              بعد از copy/move فراداده EXIF/GPS را از اهداف حذف می‌کند'
        else if S = '  --replace          overwrite existing targets' then Result := '  --replace            روی اهداف موجود می‌نویسد، وگرنه نام یکتای ~(N)'
        else if S = 'Found %s file(s)' then Result := '%s فایل پیدا شد'
        else if S = 'EXTRACT(%s): %s <=> delete archive' then Result := 'EXTRACT(%s): %s <=> حذف آرشیو'
        else if S = 'Unknown option: %s' then Result := 'گزینه ناشناخته: %s'
        else if S = 'Invalid --mode: %s' then Result := '--mode نامعتبر: %s'
        else if S = '--trash needs trash-put (trash-cli)' then Result := '--trash به trash-put (trash-cli) نیاز دارد'
        else if S = 'Source directory not found: %s' then Result := 'پوشه منبع پیدا نشد: %s'
        else if S = 'Unsupported language: %s (see --lang)' then Result := 'زبان پشتیبانی‌نشده: %s (ببینید --lang)'
        else if S = 'Available languages (--lang=XX):' then Result := 'زبان‌های موجود (--lang=XX):'
        else if S = 'Summary' then Result := 'خلاصه'
        else if S = 'Copied : %s' then Result := 'رونوشت : %s'
        else if S = 'Moved  : %s' then Result := 'جابه‌جا : %s'
        else if S = 'Removed: %s' then Result := 'حذف شد : %s'
        else if S = 'Trashed  : %s' then Result := 'زباله‌دان : %s'
        else if S = 'Shredded : %s' then Result := 'از بین رفته: %s'
        else if S = 'Extracted: %s' then Result := 'باز شد: %s'
        else if S = 'Preview: %s' then Result := 'پیش‌نمایش: %s'
        else if S = 'Skipped: %s' then Result := 'رد شد : %s'
        else if S = 'Failed : %s' then Result := 'ناموفق : %s'
        else if S = 'Undo script written: %s' then Result := 'اسکریپت بازگردانی نوشته شد: %s'
        else if S = 'FAILED) %s - could not extract (rc %s)' then Result := 'خطا) %s - بازگشایی ممکن نیست (rc %s)'
        else if S = 'FAILED) trash %s' then Result := 'خطا) زباله‌دان %s'
        else if S = 'FAILED) rm %s' then Result := 'خطا) حذف %s'
        else if S = 'FAILED) trash %s (rc %s)' then Result := 'خطا) زباله‌دان %s (rc %s)'
        else if S = 'FAILED) mkdir %s' then Result := 'خطا) ساخت پوشه %s'
        else if S = 'FAILED) move %s' then Result := 'خطا) جابه‌جایی %s'
        else if S = 'FAILED) copy %s' then Result := 'خطا) کپی %s'
        else if S = 'MODES:' then Result := 'حالت‌ها:'
        else if S = 'STRUCTURE:' then Result := 'مقصد و نام‌گذاری:'
        else if S = 'FILTERS / SCOPE:' then Result := 'پالایش و پردازش:'
        else if S = 'ARCHIVES:' then Result := 'آرشیوها:'
        else if S = 'EXTRAS:' then Result := 'خروجی و ایمنی:'
        else if S = 'LANGUAGES:' then Result := 'زبان‌ها:'
        else if S = '--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)' then Result := '--lang=XX          زبان رابط کاربری (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'
        else if S = '--lang             Print the language list' then Result := '--lang             چاپ فهرست زبان‌ها'
        else Result := S;
    end
    else
        Result := S;
end;

{ Tf: translate a %s template and substitute the arguments in order }
function Tf(const Tpl: String; const Args: array of String): String;
var
    R: String;
    I, P: Integer;
begin
    R := Tpl;
    for I := 0 to High(Args) do
    begin
        P := Pos('%s', R);
        if P > 0 then
            R := Copy(R, 1, P - 1) + Args[I] + Copy(R, P + 2, Length(R));
    end;
    Result := R;
end;

{ Lang_List: print the available UI languages }
procedure Lang_List;
var
    I: Integer;
begin
    WriteLn(Tr('Available languages (--lang=XX):'));
    for I := Low(LangCodes) to High(LangCodes) do
        WriteLn('  ', LangCodes[I], ' — ', Lang_Name(LangCodes[I]));
end;

{ Show_Version: print the version banner }
procedure Show_Version;
begin
    WriteLn('Sort ', ScriptVersion, ' (FreePascal 3.2.2 translation of Sort.sh)');
end;

{ Show_Usage: print the short usage reminder }
procedure Show_Usage;
begin
    WriteLn(Tr('Usage: sort [OPTIONS] [DIR...]'));
    WriteLn(Tr('Try ''sort --help'' for the full option list.'));
end;

{ Show_Help: print the full option help }
{ ------------------------------------------------------------------ }
{ MAGIC MODULE (V17.5) - --magic: magic-number detection report       }
{ Comprehensive embedded signature table (260 formats): images,   }
{ audio, video, archives, documents, fonts, executables, data and disk }
{ formats. Pure TFileStream + hex comparison. Zero external calls.      }
{ ------------------------------------------------------------------ }

function Magic_Hex(const Path: string): string;
var
    F: TFileStream;
    Buf: array[0..32773] of Byte;
    N: Integer;
    I: Integer;
begin
    Result := '';
    try
        F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
        try
            N := F.Read(Buf, 32774);
            for I := 0 to N - 1 do
                Result := Result + LowerCase(IntToHex(Buf[I], 2));
        finally
            F.Free;
        end;
    except
        Result := '';
    end;
end;

function Magic_Match(const H: string; Off: Integer; const Sig: string): Boolean;
var
    I: Integer;
begin
    Magic_Match := False;
    if Length(H) < Off * 2 + Length(Sig) then
        Exit;
    for I := 1 to Length(Sig) do
        if (Sig[I] <> '?') and (H[Off * 2 + I] <> Sig[I]) then
            Exit;
    Magic_Match := True;
end;

procedure Magic_Detect(const H: string; out Name: string; out Exts: string);
begin
    Name := '?';
    Exts := '';
    if H = '' then
        Exit;
    { MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376 }
    if (Length(H) >= 754) and (Copy(H, 1, 2) = '47')
        and (Copy(H, 377, 2) = '47') and (Copy(H, 753, 2) = '47') then
    begin Name := 'MPEG-TS'; Exts := 'ts,m2ts,mts'; Exit; end;
    if Magic_Match(H, 64, '3c3c3c3c204f7261636c6520564d2056') then begin Name := 'VirtualBox VDI disk'; Exts := 'vdi'; Exit; end;
    if Magic_Match(H, 4086, '535741505350414345') then begin Name := 'Linux swap area'; Exts := 'img'; Exit; end;
    if Magic_Match(H, 60, '424f4f4b4d4f4249') then begin Name := 'MOBI e-book'; Exts := 'mobi,prc'; Exit; end;
    if Magic_Match(H, 3, '4e54465320202020') then begin Name := 'NTFS filesystem'; Exts := 'img'; Exit; end;
    if Magic_Match(H, 64, '5f42485266535f4d') then begin Name := 'Btrfs filesystem'; Exts := 'img'; Exit; end;
    if Magic_Match(H, 32769, '4344303031') then begin Name := 'ISO 9660 image'; Exts := 'iso,img'; Exit; end;
    if Magic_Match(H, 257, '7573746172') then begin Name := 'TAR archive'; Exts := 'tar'; Exit; end;
    if Magic_Match(H, 1, '2d6c683?2d') then begin Name := 'LHA/LZH archive'; Exts := 'lzh,lha'; Exit; end;
    if Magic_Match(H, 44, '5343524d') then begin Name := 'S3M module'; Exts := 's3m'; Exit; end;
    if Magic_Match(H, 108, '4d214b21') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 108, '46545434') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 108, '46545438') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 108, '3443484e') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 108, '3643484e') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 108, '3843484e') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 8, '2142444e') then begin Name := 'Outlook PST database'; Exts := 'pst'; Exit; end;
    if Magic_Match(H, 108, '4d2e4b') then begin Name := 'Amiga MOD module'; Exts := 'mod'; Exit; end;
    if Magic_Match(H, 1080, '53ef') then begin Name := 'Linux ext2/3/4 filesystem'; Exts := 'img'; Exit; end;
    if Magic_Match(H, 0, '4c0000000114020000000000c0000000') then begin Name := 'Windows shortcut'; Exts := 'lnk'; Exit; end;
    if Magic_Match(H, 0, '457874656e646564204d6f64756c65') then begin Name := 'FastTracker XM module'; Exts := 'xm'; Exit; end;
    if Magic_Match(H, 0, '53514c69746520666f726d61742033') then begin Name := 'SQLite database'; Exts := 'db,sqlite,sqlite3'; Exit; end;
    if Magic_Match(H, 0, '437265617469766520566f696365') then begin Name := 'Creative Voice audio (VOC)'; Exts := 'voc'; Exit; end;
    if Magic_Match(H, 0, '414e44524f4944204241434b5550') then begin Name := 'Android backup'; Exts := 'ab'; Exit; end;
    if Magic_Match(H, 0, '0000000c6a5020200d0a870a') then begin Name := 'JPEG 2000 (JP2)'; Exts := 'jp2'; Exit; end;
    if Magic_Match(H, 0, '3c53746174615f6474613e') then begin Name := 'Stata dataset'; Exts := 'dta'; Exit; end;
    if Magic_Match(H, 0, '64383a616e6e6f756e6365') then begin Name := 'BitTorrent metainfo'; Exts := 'torrent'; Exit; end;
    if Magic_Match(H, 0, '233f52414449414e4345') then begin Name := 'Radiance HDR image'; Exts := 'hdr'; Exit; end;
    if Magic_Match(H, 0, '2d2d2d2d2d424547494e') then begin Name := 'Armored ASCII block (PGP/PEM/SSH)'; Exts := 'asc,pgp,gpg'; Exit; end;
    if Magic_Match(H, 0, '52494646????????57454250') then begin Name := 'WEBP image'; Exts := 'webp'; Exit; end;
    if Magic_Match(H, 0, '52494646????????57415645') then begin Name := 'WAV audio'; Exts := 'wav'; Exit; end;
    if Magic_Match(H, 0, '52494646????????41564920') then begin Name := 'AVI video'; Exts := 'avi'; Exit; end;
    if Magic_Match(H, 0, '52494646????????414d5620') then begin Name := 'AMV video'; Exts := 'amv'; Exit; end;
    if Magic_Match(H, 0, '464f524d????????41494646') then begin Name := 'AIFF audio'; Exts := 'aiff,aif'; Exit; end;
    if Magic_Match(H, 0, '464f524d????????41494643') then begin Name := 'AIFC audio'; Exts := 'aifc'; Exit; end;
    if Magic_Match(H, 0, '????????6674797071742020') then begin Name := 'QuickTime MOV video'; Exts := 'mov'; Exit; end;
    if Magic_Match(H, 0, '????????667479704d344120') then begin Name := 'M4A audio'; Exts := 'm4a'; Exit; end;
    if Magic_Match(H, 0, '????????667479704d345620') then begin Name := 'M4V video'; Exts := 'm4v'; Exit; end;
    if Magic_Match(H, 0, '????????6674797068656963') then begin Name := 'HEIC/HEIF image'; Exts := 'heic,heif,hif'; Exit; end;
    if Magic_Match(H, 0, '????????6674797068656978') then begin Name := 'HEIC/HEIF image'; Exts := 'heic,heif,hif'; Exit; end;
    if Magic_Match(H, 0, '????????6674797068656966') then begin Name := 'HEIC/HEIF image'; Exts := 'heic,heif,hif'; Exit; end;
    if Magic_Match(H, 0, '????????667479706d696631') then begin Name := 'HEIC/HEIF image'; Exts := 'heic,heif,hif'; Exit; end;
    if Magic_Match(H, 0, '????????667479706d736631') then begin Name := 'HEIC/HEIF image'; Exts := 'heic,heif,hif'; Exit; end;
    if Magic_Match(H, 0, '????????6674797061766966') then begin Name := 'AVIF image'; Exts := 'avif'; Exit; end;
    if Magic_Match(H, 0, '????????6674797061766973') then begin Name := 'AVIF image'; Exts := 'avif'; Exit; end;
    if Magic_Match(H, 0, '????????667479706a703220') then begin Name := 'JPEG 2000 (JP2)'; Exts := 'jp2'; Exit; end;
    if Magic_Match(H, 0, '????????6674797033677034') then begin Name := '3GP video'; Exts := '3gp'; Exit; end;
    if Magic_Match(H, 0, '????????6674797033677035') then begin Name := '3GP video'; Exts := '3gp'; Exit; end;
    if Magic_Match(H, 0, '????????6674797033677036') then begin Name := '3GP video'; Exts := '3gp'; Exit; end;
    if Magic_Match(H, 0, '????????6674797033673261') then begin Name := '3G2 video'; Exts := '3g2'; Exit; end;
    if Magic_Match(H, 0, '????????6674797069736f6d') then begin Name := 'MP4 video'; Exts := 'mp4'; Exit; end;
    if Magic_Match(H, 0, '????????6674797069736f32') then begin Name := 'MP4 video'; Exts := 'mp4'; Exit; end;
    if Magic_Match(H, 0, '????????667479706d703431') then begin Name := 'MP4 video'; Exts := 'mp4'; Exit; end;
    if Magic_Match(H, 0, '????????667479706d703432') then begin Name := 'MP4 video'; Exts := 'mp4'; Exit; end;
    if Magic_Match(H, 0, '????????6674797061766331') then begin Name := 'MP4 video'; Exts := 'mp4'; Exit; end;
    if Magic_Match(H, 0, '????????6674797064617368') then begin Name := 'DASH video'; Exts := 'mpd,m4s,mp4'; Exit; end;
    if Magic_Match(H, 0, '????????6674797066347620') then begin Name := 'Flash F4V video'; Exts := 'f4v'; Exit; end;
    if Magic_Match(H, 0, '52494646????????41434f4e') then begin Name := 'Windows animated cursor'; Exts := 'ani'; Exit; end;
    if Magic_Match(H, 0, '464f524d????????494c424d') then begin Name := 'Amiga ILBM image'; Exts := 'iff,lbm'; Exit; end;
    if Magic_Match(H, 0, '464f524d????????38535658') then begin Name := 'Amiga 8SVX audio'; Exts := 'iff,8svx'; Exit; end;
    if Magic_Match(H, 0, '464f524d????????4d415544') then begin Name := 'Amiga MAUD audio'; Exts := 'maud'; Exit; end;
    if Magic_Match(H, 0, '52494646????????524d4944') then begin Name := 'RIFF MIDI (RMID)'; Exts := 'rmi'; Exit; end;
    if Magic_Match(H, 0, '52494646????????7366626b') then begin Name := 'SoundFont SF2'; Exts := 'sf2'; Exit; end;
    if Magic_Match(H, 0, '????????6674797068766331') then begin Name := 'HEVC video'; Exts := 'hevc,h265'; Exit; end;
    if Magic_Match(H, 0, '????????6674797068657631') then begin Name := 'HEVC video'; Exts := 'hevc,h265'; Exit; end;
    if Magic_Match(H, 0, '????????6674797061763031') then begin Name := 'AV1 video'; Exts := 'av1'; Exit; end;
    if Magic_Match(H, 0, '????????6674797044495658') then begin Name := 'DivX video'; Exts := 'divx'; Exit; end;
    if Magic_Match(H, 0, '????????667479704d344220') then begin Name := 'M4B audiobook'; Exts := 'm4b'; Exit; end;
    if Magic_Match(H, 0, '67696d7020786366') then begin Name := 'GIMP XCF image'; Exts := 'xcf'; Exit; end;
    if Magic_Match(H, 0, '3026b2758e66cf11') then begin Name := 'ASF media (WMA/WMV)'; Exts := 'wma,wmv,asf'; Exit; end;
    if Magic_Match(H, 0, 'd0cf11e0a1b11ae1') then begin Name := 'MS Office/OLE compound'; Exts := 'doc,xls,ppt,msi,cfg'; Exit; end;
    if Magic_Match(H, 0, '41542654464f524d') then begin Name := 'DjVu document'; Exts := 'djvu,djv'; Exit; end;
    if Magic_Match(H, 0, '49544f4c49544c53') then begin Name := 'MS Reader LIT e-book'; Exts := 'lit'; Exit; end;
    if Magic_Match(H, 0, '7668647866696c65') then begin Name := 'Hyper-V VHDX disk'; Exts := 'vhdx'; Exit; end;
    if Magic_Match(H, 0, '2321414d522d5742') then begin Name := 'AMR-WB speech audio'; Exts := 'amr'; Exit; end;
    if Magic_Match(H, 0, '50532d5820455845') then begin Name := 'PlayStation executable'; Exts := 'exe'; Exit; end;
    if Magic_Match(H, 0, '414e44524f494421') then begin Name := 'Android boot image'; Exts := 'img'; Exit; end;
    if Magic_Match(H, 0, '5041474544554d50') then begin Name := 'Windows kernel dump'; Exts := 'dmp'; Exit; end;
    if Magic_Match(H, 0, '5041474544553634') then begin Name := 'Windows kernel dump (64-bit)'; Exts := 'dmp'; Exit; end;
    if Magic_Match(H, 0, '52494646????????434452') then begin Name := 'CorelDRAW document'; Exts := 'cdr'; Exit; end;
    if Magic_Match(H, 0, '213c617263683e') then begin Name := 'AR archive (deb/static lib)'; Exts := 'a,deb'; Exit; end;
    if Magic_Match(H, 0, '53747566664974') then begin Name := 'StuffIt archive'; Exts := 'sit'; Exit; end;
    if Magic_Match(H, 0, '49492a00????????4352') then begin Name := 'Canon CR2 raw image'; Exts := 'cr2'; Exit; end;
    if Magic_Match(H, 0, '233f52474245') then begin Name := 'Radiance HDR image'; Exts := 'hdr'; Exit; end;
    if Magic_Match(H, 0, '377abcaf271c') then begin Name := '7-Zip archive'; Exts := '7z'; Exit; end;
    if Magic_Match(H, 0, '526172211a07') then begin Name := 'RAR archive'; Exts := 'rar'; Exit; end;
    if Magic_Match(H, 0, '303730373031') then begin Name := 'CPIO archive (newc)'; Exts := 'cpio'; Exit; end;
    if Magic_Match(H, 0, '303730373037') then begin Name := 'CPIO archive (odc)'; Exts := 'cpio'; Exit; end;
    if Magic_Match(H, 0, '2a2a4143452a') then begin Name := 'ACE archive'; Exts := 'ace'; Exit; end;
    if Magic_Match(H, 0, '7b5c72746631') then begin Name := 'RTF document'; Exts := 'rtf'; Exit; end;
    if Magic_Match(H, 0, '4c554b53babe') then begin Name := 'LUKS encrypted volume'; Exts := 'luks,img'; Exit; end;
    if Magic_Match(H, 0, '53494d504c45') then begin Name := 'FITS astronomy image'; Exts := 'fits'; Exit; end;
    if Magic_Match(H, 0, '4152524f5731') then begin Name := 'Apache Arrow IPC data'; Exts := 'arrow'; Exit; end;
    if Magic_Match(H, 0, '4d41544c4142') then begin Name := 'MATLAB MAT-file'; Exts := 'mat'; Exit; end;
    if Magic_Match(H, 0, '0d0a870a0a') then begin Name := 'JPEG XL container'; Exts := 'jxl'; Exit; end;
    if Magic_Match(H, 0, '3c3f786d6c') then begin Name := 'XML document'; Exts := 'xml,svg,fb2,rss,xsl,plist'; Exit; end;
    if Magic_Match(H, 0, '2321414d52') then begin Name := 'AMR speech audio'; Exts := 'amr'; Exit; end;
    if Magic_Match(H, 0, 'fd377a585a') then begin Name := 'XZ stream'; Exts := 'xz,txz'; Exit; end;
    if Magic_Match(H, 0, '4d5357494d') then begin Name := 'Windows Imaging archive'; Exts := 'wim'; Exit; end;
    if Magic_Match(H, 0, '4e45534d1a') then begin Name := 'NES sound file'; Exts := 'nsf'; Exit; end;
    if Magic_Match(H, 0, '5245444953') then begin Name := 'Redis RDB snapshot'; Exts := 'rdb'; Exit; end;
    if Magic_Match(H, 0, '????????66747970') then begin Name := 'MP4/QuickTime container'; Exts := 'mp4,m4a,mov,3gp,heic'; Exit; end;
    if Magic_Match(H, 0, '89504e47') then begin Name := 'PNG image'; Exts := 'png'; Exit; end;
    if Magic_Match(H, 0, 'ff4fff51') then begin Name := 'JPEG 2000 codestream'; Exts := 'j2k,jpc'; Exit; end;
    if Magic_Match(H, 0, '47494638') then begin Name := 'GIF image'; Exts := 'gif'; Exit; end;
    if Magic_Match(H, 0, '49492a00') then begin Name := 'TIFF image (little-endian)'; Exts := 'tif,tiff'; Exit; end;
    if Magic_Match(H, 0, '4d4d002a') then begin Name := 'TIFF image (big-endian)'; Exts := 'tif,tiff'; Exit; end;
    if Magic_Match(H, 0, '38425053') then begin Name := 'Photoshop PSD image'; Exts := 'psd,pdd'; Exit; end;
    if Magic_Match(H, 0, '44445320') then begin Name := 'DirectDraw Surface texture'; Exts := 'dds'; Exit; end;
    if Magic_Match(H, 0, '762f3101') then begin Name := 'OpenEXR image'; Exts := 'exr'; Exit; end;
    if Magic_Match(H, 0, '00020000') then begin Name := 'Windows cursor'; Exts := 'cur'; Exit; end;
    if Magic_Match(H, 0, '00010000') then begin Name := 'ICO icon / TrueType font'; Exts := 'ico,ttf,otf'; Exit; end;
    if Magic_Match(H, 0, '69636e73') then begin Name := 'Apple ICNS icon'; Exts := 'icns'; Exit; end;
    if Magic_Match(H, 0, '3c737667') then begin Name := 'SVG image'; Exts := 'svg'; Exit; end;
    if Magic_Match(H, 0, '52494646') then begin Name := 'RIFF container'; Exts := 'wav,avi,webp'; Exit; end;
    if Magic_Match(H, 0, '46524d38') then begin Name := 'DSDIFF audio (DFF)'; Exts := 'dff'; Exit; end;
    if Magic_Match(H, 0, '63616666') then begin Name := 'Apple CAF audio'; Exts := 'caf'; Exit; end;
    if Magic_Match(H, 0, '44534420') then begin Name := 'DSD streamfile audio (DSF)'; Exts := 'dsf'; Exit; end;
    if Magic_Match(H, 0, '664c6143') then begin Name := 'FLAC audio'; Exts := 'flac'; Exit; end;
    if Magic_Match(H, 0, '4f676753') then begin Name := 'OGG media'; Exts := 'ogg,oga,opus,ogv,ogx'; Exit; end;
    if Magic_Match(H, 0, '4d546864') then begin Name := 'MIDI music'; Exts := 'mid,midi,rmi,kar'; Exit; end;
    if Magic_Match(H, 0, '2e736e64') then begin Name := 'NeXT/Sun AU audio'; Exts := 'au,snd'; Exit; end;
    if Magic_Match(H, 0, '4d414320') then begin Name := 'Monkey Audio (APE)'; Exts := 'ape'; Exit; end;
    if Magic_Match(H, 0, '7770766b') then begin Name := 'WavPack audio'; Exts := 'wv'; Exit; end;
    if Magic_Match(H, 0, '4d50434b') then begin Name := 'Musepack audio (SV8)'; Exts := 'mpc'; Exit; end;
    if Magic_Match(H, 0, '54544131') then begin Name := 'True Audio (TTA)'; Exts := 'tta'; Exit; end;
    if Magic_Match(H, 0, '616a6b67') then begin Name := 'Shorten audio'; Exts := 'shn'; Exit; end;
    if Magic_Match(H, 0, '494d504d') then begin Name := 'Impulse Tracker module'; Exts := 'it'; Exit; end;
    if Magic_Match(H, 0, '1a45dfa3') then begin Name := 'Matroska/WebM video'; Exts := 'mkv,webm,mka,mks'; Exit; end;
    if Magic_Match(H, 0, '000001ba') then begin Name := 'MPEG program stream'; Exts := 'mpg,mpeg,vob,ps'; Exit; end;
    if Magic_Match(H, 0, '000001b3') then begin Name := 'MPEG elementary video'; Exts := 'm2v,mpv,mpg'; Exit; end;
    if Magic_Match(H, 0, '2e524d46') then begin Name := 'RealMedia video'; Exts := 'rm,rmvb'; Exit; end;
    if Magic_Match(H, 0, '060e2b34') then begin Name := 'MXF video'; Exts := 'mxf'; Exit; end;
    if Magic_Match(H, 0, '504b0304') then begin Name := 'ZIP/Office document'; Exts := 'zip,docx,xlsx,pptx,odt,jar,apk,epub'; Exit; end;
    if Magic_Match(H, 0, '504b0506') then begin Name := 'ZIP archive (empty)'; Exts := 'zip'; Exit; end;
    if Magic_Match(H, 0, '504b0708') then begin Name := 'ZIP archive (spanned)'; Exts := 'zip'; Exit; end;
    if Magic_Match(H, 0, '28b52ffd') then begin Name := 'Zstandard stream'; Exts := 'zst'; Exit; end;
    if Magic_Match(H, 0, '04224d18') then begin Name := 'LZ4 frame'; Exts := 'lz4'; Exit; end;
    if Magic_Match(H, 0, '5d000080') then begin Name := 'LZMA-alone stream'; Exts := 'lzma'; Exit; end;
    if Magic_Match(H, 0, '894c5a4f') then begin Name := 'LZO compressed archive'; Exts := 'lzo'; Exit; end;
    if Magic_Match(H, 0, '4d534346') then begin Name := 'MS Cabinet archive'; Exts := 'cab'; Exit; end;
    if Magic_Match(H, 0, 'edabeedb') then begin Name := 'RPM package'; Exts := 'rpm'; Exit; end;
    if Magic_Match(H, 0, '50415231') then begin Name := 'Apache Parquet data'; Exts := 'parquet'; Exit; end;
    if Magic_Match(H, 0, '25504446') then begin Name := 'PDF document'; Exts := 'pdf'; Exit; end;
    if Magic_Match(H, 0, '25215053') then begin Name := 'PostScript/EPS document'; Exts := 'ps,eps,ai'; Exit; end;
    if Magic_Match(H, 0, '49545346') then begin Name := 'MS Compiled HTML (CHM)'; Exts := 'chm'; Exit; end;
    if Magic_Match(H, 0, '4f54544f') then begin Name := 'OpenType (CFF) font'; Exts := 'otf'; Exit; end;
    if Magic_Match(H, 0, '74746366') then begin Name := 'TrueType collection'; Exts := 'ttc'; Exit; end;
    if Magic_Match(H, 0, '774f4646') then begin Name := 'WOFF font'; Exts := 'woff'; Exit; end;
    if Magic_Match(H, 0, '774f4632') then begin Name := 'WOFF2 font'; Exts := 'woff2'; Exit; end;
    if Magic_Match(H, 0, '7f454c46') then begin Name := 'ELF binary'; Exts := 'so,bin,elf,o,ko'; Exit; end;
    if Magic_Match(H, 0, 'feedface') then begin Name := 'Mach-O binary (32-bit BE)'; Exts := 'bin'; Exit; end;
    if Magic_Match(H, 0, 'cefaedfe') then begin Name := 'Mach-O binary (32-bit LE)'; Exts := 'bin'; Exit; end;
    if Magic_Match(H, 0, 'feedfacf') then begin Name := 'Mach-O binary (64-bit BE)'; Exts := 'bin'; Exit; end;
    if Magic_Match(H, 0, 'cffaedfe') then begin Name := 'Mach-O binary (64-bit LE)'; Exts := 'bin'; Exit; end;
    if Magic_Match(H, 0, 'cafebabe') then begin Name := 'Java class / Mach-O fat binary'; Exts := 'class,bin'; Exit; end;
    if Magic_Match(H, 0, '0061736d') then begin Name := 'WebAssembly module'; Exts := 'wasm'; Exit; end;
    if Magic_Match(H, 0, '6465780a') then begin Name := 'Android DEX bytecode'; Exts := 'dex,odex'; Exit; end;
    if Magic_Match(H, 0, '72656766') then begin Name := 'Windows registry hive'; Exts := 'dat,hive,reg'; Exit; end;
    if Magic_Match(H, 0, 'a1b2c3d4') then begin Name := 'pcap packet capture'; Exts := 'pcap,cap'; Exit; end;
    if Magic_Match(H, 0, 'd4c3b2a1') then begin Name := 'pcap packet capture (swapped)'; Exts := 'pcap,cap'; Exit; end;
    if Magic_Match(H, 0, '0a0d0d0a') then begin Name := 'pcapng packet capture'; Exts := 'pcapng'; Exit; end;
    if Magic_Match(H, 0, '4f626a01') then begin Name := 'Apache Avro object container'; Exts := 'avro'; Exit; end;
    if Magic_Match(H, 0, '43723234') then begin Name := 'Chrome extension (CRX)'; Exts := 'crx'; Exit; end;
    if Magic_Match(H, 0, '514649fb') then begin Name := 'QEMU copy-on-write disk'; Exts := 'qcow,qcow2'; Exit; end;
    if Magic_Match(H, 0, '4b444d56') then begin Name := 'VMware VMDK disk'; Exts := 'vmdk'; Exit; end;
    if Magic_Match(H, 0, '4d4d002b') then begin Name := 'TIFF image (BigTIFF)'; Exts := 'tif,tiff'; Exit; end;
    if Magic_Match(H, 0, '4949524f') then begin Name := 'Olympus ORF raw image'; Exts := 'orf'; Exit; end;
    if Magic_Match(H, 0, '49495500') then begin Name := 'Panasonic RW2 raw image'; Exts := 'rw2'; Exit; end;
    if Magic_Match(H, 0, '4949bc01') then begin Name := 'JPEG XR image'; Exts := 'jxr,wdp,hdp'; Exit; end;
    if Magic_Match(H, 0, '464c4946') then begin Name := 'FLIF image'; Exts := 'flif'; Exit; end;
    if Magic_Match(H, 0, 'ab4b5458') then begin Name := 'KTX/KTX2 texture'; Exts := 'ktx,ktx2'; Exit; end;
    if Magic_Match(H, 0, '716f6966') then begin Name := 'QOI image'; Exts := 'qoi'; Exit; end;
    if Magic_Match(H, 0, '4f465220') then begin Name := 'OptimFROG audio'; Exts := 'ofr'; Exit; end;
    if Magic_Match(H, 0, '7fff8001') then begin Name := 'DTS audio'; Exts := 'dts'; Exit; end;
    if Magic_Match(H, 0, '50534944') then begin Name := 'Commodore SID tune'; Exts := 'sid'; Exit; end;
    if Magic_Match(H, 0, '56676d20') then begin Name := 'Video Game Music tune'; Exts := 'vgm'; Exit; end;
    if Magic_Match(H, 0, '6e75742f') then begin Name := 'NUT video'; Exts := 'nut'; Exit; end;
    if Magic_Match(H, 0, '78617221') then begin Name := 'XAR archive'; Exts := 'xar'; Exit; end;
    if Magic_Match(H, 0, '5041434b') then begin Name := 'Git packfile / Quake PAK'; Exts := 'pack,pak'; Exit; end;
    if Magic_Match(H, 0, '4d50511a') then begin Name := 'Blizzard MPQ archive'; Exts := 'mpq'; Exit; end;
    if Magic_Match(H, 0, '49574144') then begin Name := 'Doom IWAD game archive'; Exts := 'wad'; Exit; end;
    if Magic_Match(H, 0, '50574144') then begin Name := 'Doom PWAD game archive'; Exts := 'wad'; Exit; end;
    if Magic_Match(H, 0, '444d5321') then begin Name := 'Amiga DMS archive'; Exts := 'dms'; Exit; end;
    if Magic_Match(H, 0, '4e45531a') then begin Name := 'NES ROM image'; Exts := 'nes'; Exit; end;
    if Magic_Match(H, 0, '80371240') then begin Name := 'Nintendo 64 ROM'; Exts := 'n64,z64'; Exit; end;
    if Magic_Match(H, 0, '37804012') then begin Name := 'Nintendo 64 ROM (swapped)'; Exts := 'n64,v64'; Exit; end;
    if Magic_Match(H, 0, '53454741') then begin Name := 'SEGA Mega Drive ROM'; Exts := 'md,gen'; Exit; end;
    if Magic_Match(H, 0, '3f5f0300') then begin Name := 'Windows Help file'; Exts := 'hlp'; Exit; end;
    if Magic_Match(H, 0, '504e5264') then begin Name := 'eReader PDB e-book'; Exts := 'pdb'; Exit; end;
    if Magic_Match(H, 0, '3c3f7068') then begin Name := 'PHP script'; Exts := 'php'; Exit; end;
    if Magic_Match(H, 0, '4d444d50') then begin Name := 'Windows minidump'; Exts := 'dmp'; Exit; end;
    if Magic_Match(H, 0, 'aced0005') then begin Name := 'Java serialized object'; Exts := 'ser'; Exit; end;
    if Magic_Match(H, 0, 'feedfeed') then begin Name := 'Java keystore'; Exts := 'jks'; Exit; end;
    if Magic_Match(H, 0, '58465342') then begin Name := 'XFS filesystem'; Exts := 'img'; Exit; end;
    if Magic_Match(H, 0, '89484446') then begin Name := 'HDF5 dataset'; Exts := 'h5,hdf5'; Exit; end;
    if Magic_Match(H, 0, '43444601') then begin Name := 'NetCDF classic dataset'; Exts := 'nc'; Exit; end;
    if Magic_Match(H, 0, '43444602') then begin Name := 'NetCDF 64-bit dataset'; Exts := 'nc'; Exit; end;
    if Magic_Match(H, 0, '52445832') then begin Name := 'R binary data'; Exts := 'rdata,rds'; Exit; end;
    if Magic_Match(H, 0, '42414d01') then begin Name := 'BAM sequence data'; Exts := 'bam'; Exit; end;
    if Magic_Match(H, 0, '4352414d') then begin Name := 'CRAM sequence data'; Exts := 'cram'; Exit; end;
    if Magic_Match(H, 0, '44495243') then begin Name := 'Git index'; Exts := 'index'; Exit; end;
    if Magic_Match(H, 0, '4d4d443?') then begin Name := 'Amiga MED module'; Exts := 'med'; Exit; end;
    if Magic_Match(H, 0, 'ffd8ff') then begin Name := 'JPEG image'; Exts := 'jpg,jpeg,jfif'; Exit; end;
    if Magic_Match(H, 0, '0a0000') then begin Name := 'PCX image'; Exts := 'pcx'; Exit; end;
    if Magic_Match(H, 0, '0a0200') then begin Name := 'PCX image'; Exts := 'pcx'; Exit; end;
    if Magic_Match(H, 0, '0a0300') then begin Name := 'PCX image'; Exts := 'pcx'; Exit; end;
    if Magic_Match(H, 0, '0a0500') then begin Name := 'PCX image'; Exts := 'pcx'; Exit; end;
    if Magic_Match(H, 0, '494433') then begin Name := 'MP3 audio (ID3v2 tag)'; Exts := 'mp3'; Exit; end;
    if Magic_Match(H, 0, '4d502b') then begin Name := 'Musepack audio'; Exts := 'mpc'; Exit; end;
    if Magic_Match(H, 0, '464c56') then begin Name := 'Flash video (FLV)'; Exts := 'flv'; Exit; end;
    if Magic_Match(H, 0, '42494b') then begin Name := 'Bink video'; Exts := 'bik,bk2'; Exit; end;
    if Magic_Match(H, 0, '425a68') then begin Name := 'BZIP2 stream'; Exts := 'bz2,tbz2'; Exit; end;
    if Magic_Match(H, 0, '1f9d8d') then begin Name := 'compress (.Z) archive'; Exts := 'z'; Exit; end;
    if Magic_Match(H, 0, '5a4f4f') then begin Name := 'ZOO archive'; Exts := 'zoo'; Exit; end;
    if Magic_Match(H, 0, '435753') then begin Name := 'Shockwave Flash (compressed)'; Exts := 'swf'; Exit; end;
    if Magic_Match(H, 0, '465753') then begin Name := 'Shockwave Flash'; Exts := 'swf'; Exit; end;
    if Magic_Match(H, 0, '5a5753') then begin Name := 'Shockwave Flash (LZMA)'; Exts := 'swf'; Exit; end;
    if Magic_Match(H, 0, '50370a') then begin Name := 'PAM image'; Exts := 'pam'; Exit; end;
    if Magic_Match(H, 0, '4d544d') then begin Name := 'Multitracker module'; Exts := 'mtm'; Exit; end;
    if Magic_Match(H, 0, '800106') then begin Name := 'Type 1 font (PFB)'; Exts := 'pfb'; Exit; end;
    if Magic_Match(H, 0, '4f5243') then begin Name := 'Apache ORC data'; Exts := 'orc'; Exit; end;
    if Magic_Match(H, 0, 'ff0a') then begin Name := 'JPEG XL codestream'; Exts := 'jxl'; Exit; end;
    if Magic_Match(H, 0, '424d') then begin Name := 'BMP image'; Exts := 'bmp,dib'; Exit; end;
    if Magic_Match(H, 0, '5034') then begin Name := 'PBM image'; Exts := 'pbm'; Exit; end;
    if Magic_Match(H, 0, '5035') then begin Name := 'PGM image'; Exts := 'pgm'; Exit; end;
    if Magic_Match(H, 0, '5036') then begin Name := 'PPM image'; Exts := 'ppm'; Exit; end;
    if Magic_Match(H, 0, 'fffb') then begin Name := 'MP3 audio (MPEG-1)'; Exts := 'mp3'; Exit; end;
    if Magic_Match(H, 0, 'fff3') then begin Name := 'MP3 audio (MPEG-2)'; Exts := 'mp3'; Exit; end;
    if Magic_Match(H, 0, 'fff2') then begin Name := 'MP3 audio (MPEG-2.5)'; Exts := 'mp3'; Exit; end;
    if Magic_Match(H, 0, 'ffe3') then begin Name := 'MP3 audio (MPEG-2.5 LSF)'; Exts := 'mp3'; Exit; end;
    if Magic_Match(H, 0, 'fff1') then begin Name := 'AAC audio (ADTS)'; Exts := 'aac,adts'; Exit; end;
    if Magic_Match(H, 0, 'fff9') then begin Name := 'AAC audio (ADTS)'; Exts := 'aac,adts'; Exit; end;
    if Magic_Match(H, 0, '1f8b') then begin Name := 'GZIP stream'; Exts := 'gz,tgz'; Exit; end;
    if Magic_Match(H, 0, '60ea') then begin Name := 'ARJ archive'; Exts := 'arj'; Exit; end;
    if Magic_Match(H, 0, '7ffe') then begin Name := 'Bourne shell archive'; Exts := 'shar'; Exit; end;
    if Magic_Match(H, 0, '4d5a') then begin Name := 'DOS/PE executable'; Exts := 'exe,dll,sys,ocx,scr'; Exit; end;
    if Magic_Match(H, 0, '2321') then begin Name := 'Script (#!)'; Exts := 'sh,py,pl,rb,el,js,ts'; Exit; end;
end;

procedure Magic_Report(const Path: string);
var
    H, Name, Exts, Ext, Verdict: string;
begin
    H := Magic_Hex(Path);
    if H = '' then
        H := '(empty)';
    Magic_Detect(LowerCase(H), Name, Exts);
    Ext := LowerCase(ExtractFileExt(Path));
    Delete(Ext, 1, 1);
    if Ext = '' then
        Ext := '(none)';
    Verdict := 'UNKNOWN';
    if Name <> '?' then
    begin
        if Ext = '(none)' then
            Verdict := 'NO-EXT'
        else if Pos(',' + Ext + ',', ',' + Exts + ',') > 0 then
            Verdict := 'MATCH'
        else
            Verdict := 'MISMATCH';
    end;
    WriteLn(Path);
    WriteLn(#9'magic: ', Copy(H, 1, 32));
    WriteLn(#9'detected: ', Name);
    WriteLn(#9'extension: ', Ext);
    WriteLn(#9'verdict: ', Verdict);
end;

procedure Magic_Report_All;
var
    I: Integer;
begin
    for I := 0 to Files.Count - 1 do
        Magic_Report(Files[I]);
end;

{ ------------------------------------------------------------------ }
{ RAW SCAN MODULE (V20) - --scan-raw: raw device signature scan      }
{ Scans a raw device (/dev/sdX) or a disk image with the same        }
{ 260 signatures as --magic. Print (default) reports the hits;      }
{ copy carves fragments into Target_Dir/RAW-CARVE with format-aware }
{ end detection. The device is opened read-only; move/remove/trash/ }
{ shred are refused. Pure TFileStream. Zero external calls.          }
{ ------------------------------------------------------------------ }

const
    Raw_Block    = 1024 * 1024;
    Raw_Carry    = 32800;          { max entry offset + max signature }
    Raw_CarveMax = 5 * 1024 * 1024;

type
    TRawEntry = record
        Off: Integer;
        Sig, Name, Exts: string;
        AnchorHex: string;         { literal hex located with PosEx }
        AnchorNibble: Integer;     { nibble index of the anchor }
    end;

    TRawHit = record
        Offset: Int64;
        Entry: Integer;
        Size: Int64;
        Exact: Boolean;
    end;

var
    RawEntries: array of TRawEntry;
    RawDevice: string = '';
    RawPending: Boolean = False;
    FsDevice: string = '';
    FsFormatsArg: string = '';
    FsPending: Boolean = False;

function Raw_HexVal(const H: string): Int64;
var
    I: Integer;
    D: Int64;
begin
    Result := 0;
    for I := 1 to Length(H) do
    begin
        case H[I] of
            '0'..'9': D := Ord(H[I]) - Ord('0');
            'a'..'f': D := Ord(H[I]) - Ord('a') + 10;
        else
            D := 0;
        end;
        Result := Result * 16 + D;
    end;
end;

const
    RawHexChars = '0123456789abcdef';

function Raw_BytesToHex(const B: array of Byte; N: Integer): string;
var
    I: Integer;
begin
    Result := '';
    SetLength(Result, N * 2);
    for I := 0 to N - 1 do
    begin
        Result[I * 2 + 1] := RawHexChars[B[I] div 16 + 1];
        Result[I * 2 + 2] := RawHexChars[B[I] mod 16 + 1];
    end;
end;

procedure Raw_Add(Off: Integer; const Sig, Name, Exts: string);
var
    N: Integer;
    BestLen, BestStart, I, J, E2, S: Integer;
begin
    N := Length(RawEntries);
    SetLength(RawEntries, N + 1);
    RawEntries[N].Off := Off;
    RawEntries[N].Sig := Sig;
    RawEntries[N].Name := Name;
    RawEntries[N].Exts := Exts;
    if Pos('?', Sig) = 0 then
    begin
        RawEntries[N].AnchorHex := Sig;
        RawEntries[N].AnchorNibble := 0;
        Exit;
    end;
    { longest even-aligned even-length known run (>= 4 hex) }
    BestLen := 0; BestStart := -1;
    I := 1;
    while I <= Length(Sig) do
    begin
        if Sig[I] = '?' then
        begin
            Inc(I);
            Continue;
        end;
        J := I;
        while (J <= Length(Sig)) and (Sig[J] <> '?') do
            Inc(J);
        for S := I to J - 1 do
        begin
            E2 := J - 1;
            while ((E2 - S + 1) mod 2) <> 0 do
                Dec(E2);
            if ((S - 1) mod 2 = 0) and (E2 - S + 1 >= BestLen)
                and (E2 - S + 1 >= 4) then
            begin
                BestLen := E2 - S + 1;
                BestStart := S;
            end;
        end;
        I := J;
    end;
    if BestStart < 0 then
    begin
        { cannot anchor: skip by giving it an impossible anchor }
        RawEntries[N].AnchorHex := '';
        RawEntries[N].AnchorNibble := 0;
    end
    else
    begin
        RawEntries[N].AnchorHex := Copy(Sig, BestStart, BestLen);
        RawEntries[N].AnchorNibble := BestStart - 1;
    end;
end;

procedure Raw_Init;
begin
    if Length(RawEntries) > 0 then
        Exit;
    Raw_Add(64, '3c3c3c3c204f7261636c6520564d2056', 'VirtualBox VDI disk', 'vdi');
    Raw_Add(4086, '535741505350414345', 'Linux swap area', 'img');
    Raw_Add(60, '424f4f4b4d4f4249', 'MOBI e-book', 'mobi,prc');
    Raw_Add(3, '4e54465320202020', 'NTFS filesystem', 'img');
    Raw_Add(64, '5f42485266535f4d', 'Btrfs filesystem', 'img');
    Raw_Add(32769, '4344303031', 'ISO 9660 image', 'iso,img');
    Raw_Add(257, '7573746172', 'TAR archive', 'tar');
    Raw_Add(1, '2d6c683?2d', 'LHA/LZH archive', 'lzh,lha');
    Raw_Add(44, '5343524d', 'S3M module', 's3m');
    Raw_Add(108, '4d214b21', 'Amiga MOD module', 'mod');
    Raw_Add(108, '46545434', 'Amiga MOD module', 'mod');
    Raw_Add(108, '46545438', 'Amiga MOD module', 'mod');
    Raw_Add(108, '3443484e', 'Amiga MOD module', 'mod');
    Raw_Add(108, '3643484e', 'Amiga MOD module', 'mod');
    Raw_Add(108, '3843484e', 'Amiga MOD module', 'mod');
    Raw_Add(8, '2142444e', 'Outlook PST database', 'pst');
    Raw_Add(108, '4d2e4b', 'Amiga MOD module', 'mod');
    Raw_Add(1080, '53ef', 'Linux ext2/3/4 filesystem', 'img');
    Raw_Add(0, '4c0000000114020000000000c0000000', 'Windows shortcut', 'lnk');
    Raw_Add(0, '457874656e646564204d6f64756c65', 'FastTracker XM module', 'xm');
    Raw_Add(0, '53514c69746520666f726d61742033', 'SQLite database', 'db,sqlite,sqlite3');
    Raw_Add(0, '437265617469766520566f696365', 'Creative Voice audio (VOC)', 'voc');
    Raw_Add(0, '414e44524f4944204241434b5550', 'Android backup', 'ab');
    Raw_Add(0, '0000000c6a5020200d0a870a', 'JPEG 2000 (JP2)', 'jp2');
    Raw_Add(0, '3c53746174615f6474613e', 'Stata dataset', 'dta');
    Raw_Add(0, '64383a616e6e6f756e6365', 'BitTorrent metainfo', 'torrent');
    Raw_Add(0, '233f52414449414e4345', 'Radiance HDR image', 'hdr');
    Raw_Add(0, '7801730d626260', 'Apple DMG disk image', 'dmg');
    Raw_Add(0, '636f6e6563746978', 'Virtual PC VHD disk image', 'vhd');
    Raw_Add(0, '4349534f', 'Compressed ISO image (CSO)', 'cso');
    Raw_Add(0, '445644', 'DVD IFO navigation file', 'ifo');
    Raw_Add(0, '02647373', 'Digital Speech Standard audio', 'dss');
    Raw_Add(0, '23204469736b2044', 'VMware VMDK descriptor', 'vmdk');
    Raw_Add(0, '7472756500', 'TrueType font (Mac)', 'ttf');
    Raw_Add(0, '425047fb', 'Better Portable Graphics image', 'bpg');
    Raw_Add(0, '424547494e3a5643', 'vCard contact file', 'vcf');
    Raw_Add(0, 'd7cdc69a', 'Windows metafile graphics', 'wmf');
    Raw_Add(0, 'c5d0d3c6', 'Encapsulated PostScript (binary)', 'eps');
    Raw_Add(0, 'cfad12fe', 'Outlook Express mail store (DBX)', 'dbx');
    Raw_Add(0, '49491a0000004845', 'Canon CRW raw photo', 'crw');
    Raw_Add(0, 'e4525c7b8cd8a74d', 'OneNote notebook', 'one');
    Raw_Add(0, '0a166f72672e626974636f696e2e7072', 'MultiBit Bitcoin wallet', 'wallet');
    Raw_Add(0, '4f50434c444154', '1Password cloud keychain', 'opvault');
    Raw_Add(0, '455646090d0aff00', 'EnCase evidence file (E01)', 'e01');
    Raw_Add(0, '0606edf5d81d46e5bd31efe7fe74b71d', 'InDesign document', 'indd');
    Raw_Add(0, '6c33336c', 'Skype user database', 'dbb');
    Raw_Add(0, '7e424b00', 'Paint Shop Pro image', 'psp');
    Raw_Add(0, '300000004c664c65', 'Windows event log (EVT)', 'evt');
    Raw_Add(0, '456c6646696c6500', 'Windows event log (EVTX)', 'evtx');
    Raw_Add(0, '434f5744', 'VMware COWD sparse disk', 'vmdk');
    Raw_Add(0, '2d2d2d2d2d424547494e', 'Armored ASCII block (PGP/PEM/SSH)', 'asc,pgp,gpg');
    Raw_Add(0, '52494646????????57454250', 'WEBP image', 'webp');
    Raw_Add(0, '52494646????????57415645', 'WAV audio', 'wav');
    Raw_Add(0, '52494646????????41564920', 'AVI video', 'avi');
    Raw_Add(0, '52494646????????414d5620', 'AMV video', 'amv');
    Raw_Add(0, '464f524d????????41494646', 'AIFF audio', 'aiff,aif');
    Raw_Add(0, '464f524d????????41494643', 'AIFC audio', 'aifc');
    Raw_Add(0, '????????6674797071742020', 'QuickTime MOV video', 'mov');
    Raw_Add(0, '????????667479704d344120', 'M4A audio', 'm4a');
    Raw_Add(0, '????????667479704d345620', 'M4V video', 'm4v');
    Raw_Add(0, '????????6674797068656963', 'HEIC/HEIF image', 'heic,heif,hif');
    Raw_Add(0, '????????6674797068656978', 'HEIC/HEIF image', 'heic,heif,hif');
    Raw_Add(0, '????????6674797068656966', 'HEIC/HEIF image', 'heic,heif,hif');
    Raw_Add(0, '????????667479706d696631', 'HEIC/HEIF image', 'heic,heif,hif');
    Raw_Add(0, '????????667479706d736631', 'HEIC/HEIF image', 'heic,heif,hif');
    Raw_Add(0, '????????6674797061766966', 'AVIF image', 'avif');
    Raw_Add(0, '????????6674797061766973', 'AVIF image', 'avif');
    Raw_Add(0, '????????667479706a703220', 'JPEG 2000 (JP2)', 'jp2');
    Raw_Add(0, '????????6674797033677034', '3GP video', '3gp');
    Raw_Add(0, '????????6674797033677035', '3GP video', '3gp');
    Raw_Add(0, '????????6674797033677036', '3GP video', '3gp');
    Raw_Add(0, '????????6674797033673261', '3G2 video', '3g2');
    Raw_Add(0, '????????6674797069736f6d', 'MP4 video', 'mp4');
    Raw_Add(0, '????????6674797069736f32', 'MP4 video', 'mp4');
    Raw_Add(0, '????????667479706d703431', 'MP4 video', 'mp4');
    Raw_Add(0, '????????667479706d703432', 'MP4 video', 'mp4');
    Raw_Add(0, '????????6674797061766331', 'MP4 video', 'mp4');
    Raw_Add(0, '????????6674797064617368', 'DASH video', 'mpd,m4s,mp4');
    Raw_Add(0, '????????6674797066347620', 'Flash F4V video', 'f4v');
    Raw_Add(0, '52494646????????41434f4e', 'Windows animated cursor', 'ani');
    Raw_Add(0, '464f524d????????494c424d', 'Amiga ILBM image', 'iff,lbm');
    Raw_Add(0, '464f524d????????38535658', 'Amiga 8SVX audio', 'iff,8svx');
    Raw_Add(0, '464f524d????????4d415544', 'Amiga MAUD audio', 'maud');
    Raw_Add(0, '52494646????????524d4944', 'RIFF MIDI (RMID)', 'rmi');
    Raw_Add(0, '52494646????????7366626b', 'SoundFont SF2', 'sf2');
    Raw_Add(0, '????????6674797068766331', 'HEVC video', 'hevc,h265');
    Raw_Add(0, '????????6674797068657631', 'HEVC video', 'hevc,h265');
    Raw_Add(0, '????????6674797061763031', 'AV1 video', 'av1');
    Raw_Add(0, '????????6674797044495658', 'DivX video', 'divx');
    Raw_Add(0, '????????667479704d344220', 'M4B audiobook', 'm4b');
    Raw_Add(0, '67696d7020786366', 'GIMP XCF image', 'xcf');
    Raw_Add(0, '3026b2758e66cf11', 'ASF media (WMA/WMV)', 'wma,wmv,asf');
    Raw_Add(0, 'd0cf11e0a1b11ae1', 'MS Office/OLE compound', 'doc,xls,ppt,msi,cfg');
    Raw_Add(0, '41542654464f524d', 'DjVu document', 'djvu,djv');
    Raw_Add(0, '49544f4c49544c53', 'MS Reader LIT e-book', 'lit');
    Raw_Add(0, '7668647866696c65', 'Hyper-V VHDX disk', 'vhdx');
    Raw_Add(0, '2321414d522d5742', 'AMR-WB speech audio', 'amr');
    Raw_Add(0, '50532d5820455845', 'PlayStation executable', 'exe');
    Raw_Add(0, '414e44524f494421', 'Android boot image', 'img');
    Raw_Add(0, '5041474544554d50', 'Windows kernel dump', 'dmp');
    Raw_Add(0, '5041474544553634', 'Windows kernel dump (64-bit)', 'dmp');
    Raw_Add(0, '52494646????????434452', 'CorelDRAW document', 'cdr');
    Raw_Add(0, '213c617263683e', 'AR archive (deb/static lib)', 'a,deb');
    Raw_Add(0, '53747566664974', 'StuffIt archive', 'sit');
    Raw_Add(0, '49492a00????????4352', 'Canon CR2 raw image', 'cr2');
    Raw_Add(0, '233f52474245', 'Radiance HDR image', 'hdr');
    Raw_Add(0, '377abcaf271c', '7-Zip archive', '7z');
    Raw_Add(0, '526172211a07', 'RAR archive', 'rar');
    Raw_Add(0, '303730373031', 'CPIO archive (newc)', 'cpio');
    Raw_Add(0, '303730373037', 'CPIO archive (odc)', 'cpio');
    Raw_Add(0, '2a2a4143452a', 'ACE archive', 'ace');
    Raw_Add(0, '7b5c72746631', 'RTF document', 'rtf');
    Raw_Add(0, '4c554b53babe', 'LUKS encrypted volume', 'luks,img');
    Raw_Add(0, '53494d504c45', 'FITS astronomy image', 'fits');
    Raw_Add(0, '4152524f5731', 'Apache Arrow IPC data', 'arrow');
    Raw_Add(0, '4d41544c4142', 'MATLAB MAT-file', 'mat');
    Raw_Add(0, '0d0a870a0a', 'JPEG XL container', 'jxl');
    Raw_Add(0, '3c3f786d6c', 'XML document', 'xml,svg,fb2,rss,xsl,plist');
    Raw_Add(0, '2321414d52', 'AMR speech audio', 'amr');
    Raw_Add(0, 'fd377a585a', 'XZ stream', 'xz,txz');
    Raw_Add(0, '4d5357494d', 'Windows Imaging archive', 'wim');
    Raw_Add(0, '4e45534d1a', 'NES sound file', 'nsf');
    Raw_Add(0, '5245444953', 'Redis RDB snapshot', 'rdb');
    Raw_Add(0, '????????66747970', 'MP4/QuickTime container', 'mp4,m4a,mov,3gp,heic');
    Raw_Add(0, '89504e47', 'PNG image', 'png');
    Raw_Add(0, 'ff4fff51', 'JPEG 2000 codestream', 'j2k,jpc');
    Raw_Add(0, '47494638', 'GIF image', 'gif');
    Raw_Add(0, '49492a00', 'TIFF image (little-endian)', 'tif,tiff');
    Raw_Add(0, '4d4d002a', 'TIFF image (big-endian)', 'tif,tiff');
    Raw_Add(0, '38425053', 'Photoshop PSD image', 'psd,pdd');
    Raw_Add(0, '44445320', 'DirectDraw Surface texture', 'dds');
    Raw_Add(0, '762f3101', 'OpenEXR image', 'exr');
    Raw_Add(0, '00020000', 'Windows cursor', 'cur');
    Raw_Add(0, '00010000', 'ICO icon / TrueType font', 'ico,ttf,otf');
    Raw_Add(0, '69636e73', 'Apple ICNS icon', 'icns');
    Raw_Add(0, '3c737667', 'SVG image', 'svg');
    Raw_Add(0, '52494646', 'RIFF container', 'wav,avi,webp');
    Raw_Add(0, '46524d38', 'DSDIFF audio (DFF)', 'dff');
    Raw_Add(0, '63616666', 'Apple CAF audio', 'caf');
    Raw_Add(0, '44534420', 'DSD streamfile audio (DSF)', 'dsf');
    Raw_Add(0, '664c6143', 'FLAC audio', 'flac');
    Raw_Add(0, '4f676753', 'OGG media', 'ogg,oga,opus,ogv,ogx');
    Raw_Add(0, '4d546864', 'MIDI music', 'mid,midi,rmi,kar');
    Raw_Add(0, '2e736e64', 'NeXT/Sun AU audio', 'au,snd');
    Raw_Add(0, '4d414320', 'Monkey Audio (APE)', 'ape');
    Raw_Add(0, '7770766b', 'WavPack audio', 'wv');
    Raw_Add(0, '4d50434b', 'Musepack audio (SV8)', 'mpc');
    Raw_Add(0, '54544131', 'True Audio (TTA)', 'tta');
    Raw_Add(0, '616a6b67', 'Shorten audio', 'shn');
    Raw_Add(0, '494d504d', 'Impulse Tracker module', 'it');
    Raw_Add(0, '1a45dfa3', 'Matroska/WebM video', 'mkv,webm,mka,mks');
    Raw_Add(0, '000001ba', 'MPEG program stream', 'mpg,mpeg,vob,ps');
    Raw_Add(0, '000001b3', 'MPEG elementary video', 'm2v,mpv,mpg');
    Raw_Add(0, '2e524d46', 'RealMedia video', 'rm,rmvb');
    Raw_Add(0, '060e2b34', 'MXF video', 'mxf');
    Raw_Add(0, '504b0304', 'ZIP/Office document', 'zip,docx,xlsx,pptx,odt,jar,apk,epub');
    Raw_Add(0, '504b0506', 'ZIP archive (empty)', 'zip');
    Raw_Add(0, '504b0708', 'ZIP archive (spanned)', 'zip');
    Raw_Add(0, '28b52ffd', 'Zstandard stream', 'zst');
    Raw_Add(0, '04224d18', 'LZ4 frame', 'lz4');
    Raw_Add(0, '5d000080', 'LZMA-alone stream', 'lzma');
    Raw_Add(0, '894c5a4f', 'LZO compressed archive', 'lzo');
    Raw_Add(0, '4d534346', 'MS Cabinet archive', 'cab');
    Raw_Add(0, 'edabeedb', 'RPM package', 'rpm');
    Raw_Add(0, '50415231', 'Apache Parquet data', 'parquet');
    Raw_Add(0, '25504446', 'PDF document', 'pdf');
    Raw_Add(0, '25215053', 'PostScript/EPS document', 'ps,eps,ai');
    Raw_Add(0, '49545346', 'MS Compiled HTML (CHM)', 'chm');
    Raw_Add(0, '4f54544f', 'OpenType (CFF) font', 'otf');
    Raw_Add(0, '74746366', 'TrueType collection', 'ttc');
    Raw_Add(0, '774f4646', 'WOFF font', 'woff');
    Raw_Add(0, '774f4632', 'WOFF2 font', 'woff2');
    Raw_Add(0, '7f454c46', 'ELF binary', 'so,bin,elf,o,ko');
    Raw_Add(0, 'feedface', 'Mach-O binary (32-bit BE)', 'bin');
    Raw_Add(0, 'cefaedfe', 'Mach-O binary (32-bit LE)', 'bin');
    Raw_Add(0, 'feedfacf', 'Mach-O binary (64-bit BE)', 'bin');
    Raw_Add(0, 'cffaedfe', 'Mach-O binary (64-bit LE)', 'bin');
    Raw_Add(0, 'cafebabe', 'Java class / Mach-O fat binary', 'class,bin');
    Raw_Add(0, '0061736d', 'WebAssembly module', 'wasm');
    Raw_Add(0, '6465780a', 'Android DEX bytecode', 'dex,odex');
    Raw_Add(0, '72656766', 'Windows registry hive', 'dat,hive,reg');
    Raw_Add(0, 'a1b2c3d4', 'pcap packet capture', 'pcap,cap');
    Raw_Add(0, 'd4c3b2a1', 'pcap packet capture (swapped)', 'pcap,cap');
    Raw_Add(0, '0a0d0d0a', 'pcapng packet capture', 'pcapng');
    Raw_Add(0, '4f626a01', 'Apache Avro object container', 'avro');
    Raw_Add(0, '43723234', 'Chrome extension (CRX)', 'crx');
    Raw_Add(0, '514649fb', 'QEMU copy-on-write disk', 'qcow,qcow2');
    Raw_Add(0, '4b444d56', 'VMware VMDK disk', 'vmdk');
    Raw_Add(0, '4d4d002b', 'TIFF image (BigTIFF)', 'tif,tiff');
    Raw_Add(0, '4949524f', 'Olympus ORF raw image', 'orf');
    Raw_Add(0, '49495500', 'Panasonic RW2 raw image', 'rw2');
    Raw_Add(0, '4949bc01', 'JPEG XR image', 'jxr,wdp,hdp');
    Raw_Add(0, '464c4946', 'FLIF image', 'flif');
    Raw_Add(0, 'ab4b5458', 'KTX/KTX2 texture', 'ktx,ktx2');
    Raw_Add(0, '716f6966', 'QOI image', 'qoi');
    Raw_Add(0, '4f465220', 'OptimFROG audio', 'ofr');
    Raw_Add(0, '7fff8001', 'DTS audio', 'dts');
    Raw_Add(0, '50534944', 'Commodore SID tune', 'sid');
    Raw_Add(0, '56676d20', 'Video Game Music tune', 'vgm');
    Raw_Add(0, '6e75742f', 'NUT video', 'nut');
    Raw_Add(0, '78617221', 'XAR archive', 'xar');
    Raw_Add(0, '5041434b', 'Git packfile / Quake PAK', 'pack,pak');
    Raw_Add(0, '4d50511a', 'Blizzard MPQ archive', 'mpq');
    Raw_Add(0, '49574144', 'Doom IWAD game archive', 'wad');
    Raw_Add(0, '50574144', 'Doom PWAD game archive', 'wad');
    Raw_Add(0, '444d5321', 'Amiga DMS archive', 'dms');
    Raw_Add(0, '4e45531a', 'NES ROM image', 'nes');
    Raw_Add(0, '80371240', 'Nintendo 64 ROM', 'n64,z64');
    Raw_Add(0, '37804012', 'Nintendo 64 ROM (swapped)', 'n64,v64');
    Raw_Add(0, '53454741', 'SEGA Mega Drive ROM', 'md,gen');
    Raw_Add(0, '3f5f0300', 'Windows Help file', 'hlp');
    Raw_Add(0, '504e5264', 'eReader PDB e-book', 'pdb');
    Raw_Add(0, '3c3f7068', 'PHP script', 'php');
    Raw_Add(0, '4d444d50', 'Windows minidump', 'dmp');
    Raw_Add(0, 'aced0005', 'Java serialized object', 'ser');
    Raw_Add(0, 'feedfeed', 'Java keystore', 'jks');
    Raw_Add(0, '58465342', 'XFS filesystem', 'img');
    Raw_Add(0, '89484446', 'HDF5 dataset', 'h5,hdf5');
    Raw_Add(0, '43444601', 'NetCDF classic dataset', 'nc');
    Raw_Add(0, '43444602', 'NetCDF 64-bit dataset', 'nc');
    Raw_Add(0, '52445832', 'R binary data', 'rdata,rds');
    Raw_Add(0, '42414d01', 'BAM sequence data', 'bam');
    Raw_Add(0, '4352414d', 'CRAM sequence data', 'cram');
    Raw_Add(0, '44495243', 'Git index', 'index');
    Raw_Add(0, '4d4d443?', 'Amiga MED module', 'med');
    Raw_Add(0, 'ffd8ff', 'JPEG image', 'jpg,jpeg,jfif');
    Raw_Add(0, '0a0000', 'PCX image', 'pcx');
    Raw_Add(0, '0a0200', 'PCX image', 'pcx');
    Raw_Add(0, '0a0300', 'PCX image', 'pcx');
    Raw_Add(0, '0a0500', 'PCX image', 'pcx');
    Raw_Add(0, '494433', 'MP3 audio (ID3v2 tag)', 'mp3');
    Raw_Add(0, '4d502b', 'Musepack audio', 'mpc');
    Raw_Add(0, '464c56', 'Flash video (FLV)', 'flv');
    Raw_Add(0, '42494b', 'Bink video', 'bik,bk2');
    Raw_Add(0, '425a68', 'BZIP2 stream', 'bz2,tbz2');
    Raw_Add(0, '1f9d8d', 'compress (.Z) archive', 'z');
    Raw_Add(0, '5a4f4f', 'ZOO archive', 'zoo');
    Raw_Add(0, '435753', 'Shockwave Flash (compressed)', 'swf');
    Raw_Add(0, '465753', 'Shockwave Flash', 'swf');
    Raw_Add(0, '5a5753', 'Shockwave Flash (LZMA)', 'swf');
    Raw_Add(0, '50370a', 'PAM image', 'pam');
    Raw_Add(0, '4d544d', 'Multitracker module', 'mtm');
    Raw_Add(0, '800106', 'Type 1 font (PFB)', 'pfb');
    Raw_Add(0, '4f5243', 'Apache ORC data', 'orc');
    Raw_Add(0, 'ff0a', 'JPEG XL codestream', 'jxl');
    Raw_Add(0, '424d', 'BMP image', 'bmp,dib');
    Raw_Add(0, '5034', 'PBM image', 'pbm');
    Raw_Add(0, '5035', 'PGM image', 'pgm');
    Raw_Add(0, '5036', 'PPM image', 'ppm');
    Raw_Add(0, 'fffb', 'MP3 audio (MPEG-1)', 'mp3');
    Raw_Add(0, 'fff3', 'MP3 audio (MPEG-2)', 'mp3');
    Raw_Add(0, 'fff2', 'MP3 audio (MPEG-2.5)', 'mp3');
    Raw_Add(0, 'ffe3', 'MP3 audio (MPEG-2.5 LSF)', 'mp3');
    Raw_Add(0, 'fff1', 'AAC audio (ADTS)', 'aac,adts');
    Raw_Add(0, 'fff9', 'AAC audio (ADTS)', 'aac,adts');
    Raw_Add(0, '1f8b', 'GZIP stream', 'gz,tgz');
    Raw_Add(0, '60ea', 'ARJ archive', 'arj');
    Raw_Add(0, '7ffe', 'Bourne shell archive', 'shar');
    Raw_Add(0, '4d5a', 'DOS/PE executable', 'exe,dll,sys,ocx,scr');
    Raw_Add(0, '2321', 'Script (#!)', 'sh,py,pl,rb,el,js,ts');
end;

function Raw_SigMatch(const H: string; Pos1: Integer; E: Integer): Boolean;
var
    I: Integer;
begin
    Result := False;
    if Length(H) < Pos1 + Length(RawEntries[E].Sig) - 1 then
        Exit;
    for I := 1 to Length(RawEntries[E].Sig) do
        if (RawEntries[E].Sig[I] <> '?')
            and (H[Pos1 + I - 1] <> RawEntries[E].Sig[I]) then
            Exit;
    Result := True;
end;

function Raw_LastPos(const H, Sub: string; From: Integer): Integer;
var
    P, Last: Integer;
begin
    Last := 0;
    P := PosEx(Sub, H, From);
    while P > 0 do
    begin
        if (P - 1) mod 2 = 0 then
            Last := P;
        P := PosEx(Sub, H, P + 1);
    end;
    Result := Last;
end;

procedure Raw_CarveSize(const H: string; const Name: string;
    out Size: Int64; out Exact: Boolean);
var
    Pos1, P, EndPos: Integer;
    Clen: Int64;
    CType: string;
begin
    Size := Length(H) div 2;
    Exact := False;
    if Size > Raw_CarveMax then
        Size := Raw_CarveMax;
    if Copy(Name, 1, 9) = 'PNG image' then
    begin
        Pos1 := 8;
        while Pos1 * 2 + 24 <= Length(H) do
        begin
            Clen := Raw_HexVal(Copy(H, Pos1 * 2 + 1, 8));
            CType := Copy(H, Pos1 * 2 + 9, 8);
            Pos1 := Pos1 + 12 + Clen;   { len + type + data + CRC }
            if CType = '49454e44' then
            begin
                Size := Pos1;
                Exact := True;
                Break;
            end;
            if Clen > Length(H) div 2 then
            begin
                Size := Pos1;
                Break;
            end;
        end;
    end
    else if Copy(Name, 1, 10) = 'JPEG image' then
    begin
        P := Raw_LastPos(H, 'ffd9', 1);
        if P > 0 then
        begin
            Size := (P - 1) div 2 + 2;
            Exact := True;
        end;
    end
    else if Copy(Name, 1, 9) = 'GIF image' then
    begin
        P := Raw_LastPos(H, '3b', 27);
        if P > 0 then
        begin
            Size := (P - 1) div 2 + 1;
            Exact := True;
        end;
    end
    else if (Copy(Name, 1, 4) = 'ZIP/') or (Copy(Name, 1, 11) = 'ZIP archive') then
    begin
        P := Raw_LastPos(H, '504b0506', 1);
        if P > 0 then
        begin
            EndPos := (P - 1) div 2;
            if EndPos + 22 <= Length(H) div 2 then
            begin
                Size := EndPos + 22
                    + Raw_HexVal(Copy(H, EndPos * 2 + 41, 2))
                    + Raw_HexVal(Copy(H, EndPos * 2 + 43, 2)) * 256;
                Exact := True;
            end;
        end;
    end
    else if Copy(Name, 1, 12) = 'PDF document' then
    begin
        P := Raw_LastPos(H, '2525454f46', 1);
        if P > 0 then
        begin
            Size := (P - 1) div 2 + 5;
            Exact := True;
        end;
    end;
    if Size > Raw_CarveMax then
        Size := Raw_CarveMax;
end;

function Raw_FirstExt(const Exts: string): string;
var
    P: Integer;
begin
    P := Pos(',', Exts);
    if (Exts = '') or (P = 1) then
        Result := 'bin'
    else if P = 0 then
        Result := Exts
    else
        Result := Copy(Exts, 1, P - 1);
end;

procedure Raw_Scan_Main;
var
    Stream, Probe, Dest: TFileStream;
    Block, Head, Carry, Window: array of Byte;
    Hex, HeadHex, Ext, OutPath: string;
    NextVal: Int64;
    Base, BufBase, N, I, E, P, SigStart: Int64;
    Hit: Int64;
    Hits: array of TRawHit;
    HitCount: Integer;
    TmpHit: TRawHit;
    J: Integer;
    Written: Int64;
begin
    if (Modus = 'move') or (Modus = 'remove') or (Modus = 'trash')
        or (Modus = 'shred') then
    begin
        WriteLn('RAW-SCAN: --scan-raw supports dummy and copy only (mode '''
            + Modus + ''' refused)');
        Halt(64);
    end;
    Raw_Init;
    Stream := nil; Probe := nil;
    try
        try
            Stream := TFileStream.Create(RawDevice, fmOpenRead or fmShareDenyNone);
            Probe := TFileStream.Create(RawDevice, fmOpenRead or fmShareDenyNone);
        except
            on EStreamError do
            begin
                WriteLn('RAW-SCAN: cannot open ' + RawDevice);
                Halt(1);
            end;
        end;
        SetLength(Block, Raw_Block);
        SetLength(Head, Raw_Block);
        SetLength(Carry, 0);
        Base := 0;
        WriteLn('RAW-SCAN: ' + RawDevice);
        if Modus = 'copy' then
        begin
            ForceDirectories(TargetDir + '/RAW-CARVE');
        end;
        HitCount := 0;
        SetLength(Hits, 0);
        while True do
        begin
            N := Stream.Read(Block[0], Raw_Block);
            if N <= 0 then
                Break;
            SetLength(Window, Length(Carry) + N);
            if Length(Carry) > 0 then
                Move(Carry[0], Window[0], Length(Carry));
            Move(Block[0], Window[Length(Carry)], N);
            Hex := Raw_BytesToHex(Window, Length(Window));
            BufBase := Base - Length(Carry);
            for E := 0 to Length(RawEntries) - 1 do
            begin
                if RawEntries[E].AnchorHex = '' then
                    Continue;
                if (Length(RawEntries[E].Sig) < 4) then
                    Continue;
                P := PosEx(RawEntries[E].AnchorHex, Hex, 1);
                while P > 0 do
                begin
                    if (P - 1) mod 2 = 0 then
                    begin
                        SigStart := (P - 1) - RawEntries[E].AnchorNibble;
                        if (SigStart mod 2 = 0) and (SigStart >= 0) then
                        begin
                            if Raw_SigMatch(Hex, SigStart + 1, E) then
                            begin
                                Hit := BufBase + SigStart div 2
                                    - RawEntries[E].Off;
                                if Hit >= 0 then
                                begin
                                    Inc(HitCount);
                                    SetLength(Hits, HitCount);
                                    Hits[HitCount - 1].Offset := Hit;
                                    Hits[HitCount - 1].Entry := E;
                                    Hits[HitCount - 1].Size := 0;
                                    Hits[HitCount - 1].Exact := False;
                                end;
                            end;
                        end;
                    end;
                    P := PosEx(RawEntries[E].AnchorHex, Hex, P + 1);
                end;
            end;
            Base := Base + N;
            if Length(Window) > Raw_Carry then
            begin
                SetLength(Carry, Raw_Carry);
                Move(Window[Length(Window) - Raw_Carry], Carry[0], Raw_Carry);
            end
            else
            begin
                SetLength(Carry, Length(Window));
                if Length(Window) > 0 then
                    Move(Window[0], Carry[0], Length(Window));
            end;
        end;
        { --- second pass: sort hits by offset, carve sizes, report --- }
        for I := 0 to HitCount - 1 do
            for J := I + 1 to HitCount - 1 do
                if Hits[J].Offset < Hits[I].Offset then
                begin
                    TmpHit := Hits[I];
                    Hits[I] := Hits[J];
                    Hits[J] := TmpHit;
                end;
        NextVal := 0;
        for I := 0 to HitCount - 1 do
        begin
            if Hits[I].Offset < NextVal then
                Continue;
            E := Hits[I].Entry;
            Probe.Seek(Hits[I].Offset, soFromBeginning);
            N := Probe.Read(Head[0], Raw_Block);
            HeadHex := Raw_BytesToHex(Head, N);
            Raw_CarveSize(HeadHex, RawEntries[E].Name, Hits[I].Size,
                Hits[I].Exact);
            if Hits[I].Exact then
                NextVal := Hits[I].Offset + Hits[I].Size
            else
                NextVal := Hits[I].Offset + 1;
            Ext := Raw_FirstExt(RawEntries[E].Exts);
            WriteLn('  hit: 0x' + LowerCase(IntToHex(Hits[I].Offset, 12))
                + ' ' + IntToStr(Hits[I].Offset) + ' ' + RawEntries[E].Name
                + ' -> ' + Ext + ' (carve ' + IntToStr(Hits[I].Size)
                + ' bytes' + IfThen(Hits[I].Exact, '', ', capped') + ')');
            if Modus = 'copy' then
            begin
                OutPath := TargetDir + '/RAW-CARVE/'
                    + LowerCase(IntToHex(Hits[I].Offset, 12)) + '.' + Ext;
                Dest := TFileStream.Create(OutPath, fmCreate);
                try
                    Stream.Seek(Hits[I].Offset, soFromBeginning);
                    Written := 0;
                    while Written < Hits[I].Size do
                    begin
                        if Hits[I].Size - Written < Raw_Block then
                            N := Hits[I].Size - Written
                        else
                            N := Raw_Block;
                        N := Stream.Read(Head[0], N);
                        if N <= 0 then
                            Break;
                        Dest.Write(Head[0], N);
                        Written := Written + N;
                    end;
                finally
                    Dest.Free;
                end;
                WriteLn('  carved: ' + OutPath);
                if LogFile <> '' then
                    Out_Log('{"action": "carved", "src": "' + RawDevice
                        + '@' + IntToStr(Hits[I].Offset) + '", "dst": "'
                        + OutPath + '"}');
            end;
        end;
        WriteLn('RAW-SCAN: ' + IntToStr(HitCount) + ' signatures found');
    finally
        Stream.Free;
        Probe.Free;
    end;
end;

procedure Show_Help;
begin
    Show_Version;
    WriteLn('');
    WriteLn(Tr('Ejder file organizer - FreePascal translation of Sort.sh v21'));
    WriteLn('');
    WriteLn(Tr('MODES:'));
    WriteLn('  --mode=MODE        print (default) / copy / move / remove / trash / shred');
    WriteLn(Tr('  --copy --move      shortcuts for --mode='));
    WriteLn(Tr('  --remove --delete  shortcut for --mode=remove'));
    WriteLn(Tr('  --trash --shred    shortcuts for --mode='));
    WriteLn('');
    WriteLn(Tr('STRUCTURE:'));
    WriteLn(Tr('  --dirs=LEVELS      directory levels, comma/plus separated:'));
    WriteLn('                     year created modified accessed mime mime-main mime-sub');
    WriteLn('                     mime-ext extension size format md5 sha1 sha256 sha512');
    WriteLn('                     sha random duration camera exifdate title compressed');
    WriteLn('                     folder folder_name (unknown values are used literally)');
    WriteLn('  --subdirs=LEVELS   same values, added below --dirs');
    WriteLn('  --extension=VALUE  none / mime / mime-sub / mime-ext / extension / literal');
    WriteLn('  --rename=VALUE     sha / sha256 / md5 / compressed / title ...');
    WriteLn('  --title            shortcut for --rename=title');
    WriteLn('');
    WriteLn(Tr('FILTERS / SCOPE:'));
    WriteLn(Tr('  --type=VALUE       only files whose MIME contains VALUE'));
    WriteLn('  --source=DIR       start point (default: current directory)');
    WriteLn(Tr('  --target=DIR       root for the new tree (default: current directory)'));
    WriteLn(Tr('  --recursive        walk subdirectories (default: non-recursive)'));
    WriteLn(Tr('  --hidden           include hidden files'));
    WriteLn(Tr('  --links            include symbolic links'));
    WriteLn('');
    WriteLn(Tr('ARCHIVES:'));
    WriteLn(Tr('  --decompress       extract archives first and process the contents'));
    WriteLn(Tr('  --rename=compressed  rename archive to its main inner directory/file'));
    WriteLn('');
    WriteLn(Tr('EXTRAS:'));
    WriteLn(Tr('  --magic            print a magic-number detection report (260 formats) and exit'));
    WriteLn(Tr('  --scan-raw=DEVICE  scan raw device/disk image (260 signatures); copy carves'));
    WriteLn(Tr('  --scan=FSFORMAT    scan a raw device or image for partitions (listed + lost), then the selected filesystems for files/lost data; FORMATS: all,ntfs,exfat,fat12,fat16,fat32,ext,btrfs,xfs,reiserfs,hfs,swap,luks; copy carves'));
    WriteLn(Tr('  --exif             add <Camera>/<Date> levels (needs exiftool)'));
    WriteLn(Tr('  --strip            strip EXIF from processed files (needs exiftool)'));
    WriteLn(Tr('  --replace          overwrite existing targets'));
    WriteLn(Tr('  --jobs=N           parallel workers (default: 1)'));
    WriteLn(Tr('  --pause=SEC        sleep between files'));
    WriteLn(Tr('  --log=FILE         append an action log'));
    WriteLn(Tr('  --undo[=FILE]      write an inverse shell script'));
    WriteLn(Tr('  --colored          ANSI-colored output'));
    WriteLn('  ' + Tr('--lang=XX          UI language (en zh hi es fr ar bn pt ru ur id de ja tr ko vi it pl nl fa)'));
    WriteLn('  ' + Tr('--lang             Print the language list'));
    WriteLn('  --quiet --verbose --stats');
    WriteLn('  --self-test        run built-in checks');
    WriteLn('  --usage --help --version');
    WriteLn('');
    WriteLn(Tr('LANGUAGES:'));
    Lang_List;
    WriteLn('');
end;

{ ------------------------------------------------------------------ }
{ Argument parsing                                                    }
{ ------------------------------------------------------------------ }

{ Opt_Value: value part of an --option=value argument }
function Opt_Value(const Arg: string): string;
begin
    Result := Copy(Arg, Pos('=', Arg) + 1, MaxInt);
end;

{ Parse_Arguments: parse the command line into the option variables }
procedure Parse_Arguments;
var
    I: Integer;
    A, K: string;
begin
    I := 1;
    while I <= ParamCount do
    begin
        A := ParamStr(I);
        if Copy(A, 1, 2) = '--' then
        begin
            K := LowerCase(A);
            if Pos('=', A) > 0 then
                K := LowerCase(Copy(A, 1, Pos('=', A) - 1));
            if K = '--mode' then
                Modus := LowerCase(Opt_Value(A))
            else if K = '--dirs' then
                DirList := Opt_Value(A)
            else if K = '--subdirs' then
                SubList := Opt_Value(A)
            else if K = '--rename' then
                RenameVal := LowerCase(Opt_Value(A))
            else if K = '--extension' then
                ExtensionVal := LowerCase(Opt_Value(A))
            else if K = '--type' then
                TypeFilter := Opt_Value(A)
            else if K = '--source' then
                SourceDir := Opt_Value(A)
            else if K = '--target' then
                TargetDir := Opt_Value(A)
            else if K = '--pause' then
                PauseSec := StrToIntDef(Opt_Value(A), 0)
            else if K = '--log' then
                LogFile := Opt_Value(A)
            else if K = '--undo' then
            begin
                UndoFile := 'sort-undo.sh';
                if Pos('=', A) > 0 then
                    UndoFile := Opt_Value(A);
            end
            else if K = '--jobs' then
                JobCount := StrToIntDef(Opt_Value(A), 1)
            else if K = '--copy' then
                Modus := 'copy'
            else if K = '--move' then
                Modus := 'move'
            else if K = '--remove' then
                Modus := 'remove'
            else if K = '--delete' then
                Modus := 'remove'
            else if K = '--trash' then
                Modus := 'trash'
            else if K = '--shred' then
                Modus := 'shred'
            else if K = '--replace' then
                DoReplace := True
            else if K = '--recursive' then
                DoRecursive := True
            else if K = '--hidden' then
                DoHidden := True
            else if K = '--links' then
                DoLinks := True
            else if (K = '--colored') or (K = '--colors') then
                DoColored := True
            else if K = '--quiet' then
                DoQuiet := True
            else if K = '--verbose' then
                DoVerbose := True
            else if K = '--stats' then
                DoStats := True
            else if K = '--strip' then
                DoStrip := True
            else if K = '--exif' then
                DoExif := True
            else if K = '--decompress' then
                DoDecompress := True
            else if K = '--title' then
                RenameVal := 'title'
            else if K = '--self-test' then
                DoSelfTest := True
            else if K = '--lang' then
            begin
                if Pos('=', A) > 0 then
                    Lang := LowerCase(Opt_Value(A))
                else
                begin
                    Lang_List;
                    Halt(0);
                end;
            end
            else if K = '--magic' then
            begin
                Magic_Mode := True
            end
            else if K = '--scan-raw' then
            begin
                if Pos('=', A) > 0 then
                    RawDevice := Opt_Value(A)
                else
                    RawPending := True
            end
            else if K = '--scan' then
            begin
                if Pos('=', A) > 0 then
                    FsFormatsArg := Opt_Value(A)
                else
                    FsPending := True
            end
            else if K = '--usage' then
            begin
                Show_Usage;
                Halt(0);
            end
            else if (K = '--help') or (K = '-h') then
            begin
                Show_Help;
                Halt(0);
            end
            else if K = '--version' then
            begin
                Show_Version;
                Halt(0);
            end
            else
            begin
                Out_Err(Tf(Tr('Unknown option: %s'), [A]));
                Show_Usage;
                Halt(2);
            end;
        end
        else
        begin
            if RawPending then
            begin
                RawDevice := A;
                RawPending := False;
            end
            else if FsPending then
            begin
                FsDevice := A;
                FsPending := False;
            end
            else
                SourceDir := A;  { positional: start directory }
        end
        I := I + 1;
    end;
end;

{ FS SCAN MODULE (V21) - --scan=FSFormat: partitions + per-partition scan  }
{ ========================================================================= }
{ Two phases: (1) partition discovery from MBR/GPT plus a 512-byte-aligned }
{ filesystem-signature probe that also finds deleted/lost partitions,      }
{ (2) the V20 signature engine runs inside each selected partition; a      }
{ fragment that crosses the partition end or overlaps another partition is  }
{ marked "broken" (overwritten data). Dummy reports only, copy carves to    }
{ Target/FS-CARVE. The source is only ever opened read-only.                }

type
    TFsPart = record
        StartV, SizeV: Int64;
        Fs: string;
        Listed, Used: Boolean;
    end;
    TFsPartArray = array of TFsPart;

const
    Fs_Formats = 'all,ntfs,exfat,fat12,fat16,fat32,ext,btrfs,xfs,reiserfs,hfs,swap,luks';

function Fs_Norm(S: string): string;
begin
    Result := LowerCase(Trim(S));
    if (Result = 'ext2') or (Result = 'ext3') or (Result = 'ext4') then
        Result := 'ext';
    if (Result = 'hfs+') or (Result = 'hfsx') or (Result = 'hfsplus') then
        Result := 'hfs';
end;

function Fs_Known(const Token: string): Boolean;
begin
    Result := Pos(',' + Token + ',', ',' + Fs_Formats + ',') > 0;
end;

function Fs_Le32(const H: string; C: Integer): Int64;
var
    K: Integer;
    B: Int64;
begin
    Result := 0;
    for K := 0 to 3 do
    begin
        B := StrToIntDef('$' + Copy(H, C + K * 2, 2), 0);
        Result := Result + (B shl (8 * K));
    end;
end;

function Fs_Le64(const H: string; C: Integer): Int64;
var
    K: Integer;
    B: Int64;
begin
    Result := 0;
    for K := 0 to 7 do
    begin
        B := StrToIntDef('$' + Copy(H, C + K * 2, 2), 0);
        Result := Result + (B shl (8 * K));
    end;
end;

{ Fs_Probe_Hex: filesystem token for a partition-start hex window, or '' }
function Fs_Probe_Hex(const H: string): string;
begin
    Result := '';
    if Copy(H, 1, 12) = '4c554b53babe' then begin Result := 'luks'; Exit; end;
    if Copy(H, 7, 16) = '4e54465320202020' then begin Result := 'ntfs'; Exit; end;
    if Copy(H, 7, 12) = '455846415420' then begin Result := 'exfat'; Exit; end;
    if Copy(H, 109, 10) = '4641543136' then begin Result := 'fat16'; Exit; end;
    if Copy(H, 109, 10) = '4641543132' then begin Result := 'fat12'; Exit; end;
    if Copy(H, 165, 10) = '4641543332' then begin Result := 'fat32'; Exit; end;
    if Copy(H, 129, 16) = '5f42485266535f4d' then begin Result := 'btrfs'; Exit; end;
    if Copy(H, 1, 8) = '58465342' then begin Result := 'xfs'; Exit; end;
    if Copy(H, 105, 12) = '526549734572' then begin Result := 'reiserfs'; Exit; end;
    if (Copy(H, 2049, 4) = '482b') or (Copy(H, 2049, 4) = '4858') then begin Result := 'hfs'; Exit; end;
    if Copy(H, 2161, 4) = '53ef' then begin Result := 'ext'; Exit; end;
    if Copy(H, 2105, 20) = '53574150535041434532' then begin Result := 'swap'; Exit; end;
end;

{ Fs_Device_Size: byte size of the open stream (0 if unknown) }
function Fs_Device_Size(S: TFileStream): Int64;
begin
    Result := S.Size;
    if Result > 0 then
        Exit;
    Result := 0;
{$IFDEF LINUX}
    try
        if FpIoctl(LongInt(S.Handle), $80081272, Result) <> 0 then
            Result := 0;
    except
        Result := 0;
    end;
{$ENDIF}
end;

{ Fs_Inside_Listed: True when Off falls into a listed partition }
function Fs_Inside_Listed(const Parts: TFsPartArray; Off: Int64): Boolean;
var
    I: Integer;
begin
    Result := False;
    for I := 0 to Length(Parts) - 1 do
        if Parts[I].Listed and (Off >= Parts[I].StartV) and
           (Off < Parts[I].StartV + Parts[I].SizeV) then
            Exit(True);
end;

{ Fs_Listed: MBR + GPT entries -> Parts (listed only) }
procedure Fs_Listed(S: TFileStream; Fsize: Int64; var Parts: TFsPartArray);
var
    H, G: string;
    Buf: array of Byte;
    N, I, K, Tb: Integer;
    Lba, Nsec, Start, Size, Elba, Nent, Esz, First, Last: Int64;
    Any: Boolean;
begin
    SetLength(Parts, 0);
    SetLength(Buf, 512);
    S.Seek(0, soFromBeginning);
    N := S.Read(Buf[0], 512);
    if N <> 512 then
        Exit;
    H := Raw_BytesToHex(Buf, 512);
    if Copy(H, 1021, 4) <> '55aa' then
        Exit;
    { GPT protective MBR? }
    if (Copy(H, 893, 2) = 'ee') or (Copy(H, 925, 2) = 'ee') or
       (Copy(H, 957, 2) = 'ee') or (Copy(H, 989, 2) = 'ee') then
    begin
        SetLength(Buf, 512);
        S.Seek(512, soFromBeginning);
        N := S.Read(Buf[0], 512);
        if N <> 512 then
            Exit;
        G := Raw_BytesToHex(Buf, 512);
        if Copy(G, 1, 16) = '4546492050415254' then
        begin
            Elba := Fs_Le64(G, 145);
            Nent := Fs_Le32(G, 161);
            Esz := Fs_Le32(G, 169);
            if (Esz >= 128) and (Nent > 0) and (Nent * Esz <= 4 * 1024 * 1024) then
            begin
                SetLength(Buf, Nent * Esz);
                S.Seek(Elba * 512, soFromBeginning);
                N := S.Read(Buf[0], Nent * Esz);
                if N = Nent * Esz then
                begin
                    G := Raw_BytesToHex(Buf, N);
                    for K := 0 to Nent - 1 do
                    begin
                        Any := False;
                        for I := 1 to 32 do
                            if G[K * Esz * 2 + I] <> '0' then
                                Any := True;
                        if not Any then
                            Continue;
                        First := Fs_Le64(G, K * Esz * 2 + 65);
                        Last := Fs_Le64(G, K * Esz * 2 + 81);
                        if Last < First then
                            Continue;
                        Start := First * 512;
                        Size := (Last - First + 1) * 512;
                        if (Size > 0) and (Start + Size <= Fsize) then
                        begin
                            SetLength(Parts, Length(Parts) + 1);
                            Parts[Length(Parts) - 1].StartV := Start;
                            Parts[Length(Parts) - 1].SizeV := Size;
                            Parts[Length(Parts) - 1].Fs := '';
                            Parts[Length(Parts) - 1].Listed := True;
                        end;
                    end;
                end;
            end;
            Exit;
        end;
    end;
    { classic MBR entries }
    for I := 0 to 3 do
    begin
        Tb := StrToIntDef('$' + Copy(H, (446 + 16 * I + 5) * 2, 2), 0);
        if (Tb = 0) or (Tb = 5) or (Tb = 15) or (Tb = 85) or (Tb = 238) then
            Continue;
        Lba := Fs_Le32(H, (446 + 16 * I + 9) * 2);
        Nsec := Fs_Le32(H, (446 + 16 * I + 13) * 2);
        if Nsec <= 0 then
            Continue;
        Start := Lba * 512;
        Size := Nsec * 512;
        if Start + Size <= Fsize then
        begin
            SetLength(Parts, Length(Parts) + 1);
            Parts[Length(Parts) - 1].StartV := Start;
            Parts[Length(Parts) - 1].SizeV := Size;
            Parts[Length(Parts) - 1].Fs := '';
            Parts[Length(Parts) - 1].Listed := True;
        end;
    end;
end;

{ Fs_Broken: fragment leaves its partition or crosses into another one }
function Fs_Broken(const Parts: TFsPartArray; Idx: Integer;
    Hit, Size: Int64): Boolean;
var
    I: Integer;
begin
    Result := False;
    if Hit + Size > Parts[Idx].StartV + Parts[Idx].SizeV then
        Exit(True);
    for I := 0 to Length(Parts) - 1 do
    begin
        if I = Idx then
            Continue;
        if (Hit < Parts[I].StartV + Parts[I].SizeV) and
           (Hit + Size > Parts[I].StartV) then
            Exit(True);
    end;
end;

procedure Fs_Scan_Main;
var
    S, Src, Dest: TFileStream;
    Parts, All: TFsPartArray;
    Hits: array of TRawHit;
    TmpHit: TRawHit;
    Block, Head, Carry, Window, WBuf: array of Byte;
    H, HeadHex, Ext, OutPath, OutDir, Tok, Forms, NewT: string;
    Base, BufBase, N, I, J, E, P, SigStart, Hit, Lo, Hi, NextVal: Int64;
    Parts2: TFsPartArray;
    K: Integer;
    Off, Est, Fsize, Written, Total: Int64;
    Count, HitCount, NList, Scanned, NParts: Integer;
    Found, Broken, Sel: Boolean;
    Formats: TStringList;
    Rec: TFsPart;
begin
    if (Modus = 'move') or (Modus = 'remove') or (Modus = 'trash')
        or (Modus = 'shred') then
    begin
        WriteLn('SCAN: --scan supports dummy and copy only (mode '''
            + Modus + ''' refused)');
        Halt(64);
    end;
    Formats := TStringList.Create;
    try
        Forms := FsFormatsArg;
        if Forms = '' then
            Forms := 'all';
        while Pos(',', Forms) > 0 do
            Forms := StringReplace(Forms, ',', ' ', [rfReplaceAll]);
        Forms := Trim(Forms);
        while Forms <> '' do
        begin
            if Pos(' ', Forms) > 0 then
            begin
                Tok := Copy(Forms, 1, Pos(' ', Forms) - 1);
                Delete(Forms, 1, Pos(' ', Forms));
            end
            else
            begin
                Tok := Forms;
                Forms := '';
            end;
            Tok := Fs_Norm(Tok);
            if Tok = '' then
                Continue;
            if not Fs_Known(Tok) then
            begin
                WriteLn('SCAN: unknown filesystem format ''' + Tok
                    + ''' (known: ' + Fs_Formats + ')');
                Halt(64);
            end;
            if Formats.IndexOf(Tok) < 0 then
                Formats.Add(Tok);
        end;
        if Formats.Count = 0 then
            Formats.Add('all');
    finally
    end;
    Raw_Init;
    S := nil; Src := nil;
    try
        try
            S := TFileStream.Create(FsDevice, fmOpenRead or fmShareDenyNone);
        except
            on EStreamError do
            begin
                WriteLn('SCAN: cannot open ' + FsDevice);
                Halt(66);
            end;
        end;
        Fsize := Fs_Device_Size(S);
        if Fsize <= 0 then
        begin
            WriteLn('SCAN: cannot determine size of ' + FsDevice);
            Halt(66);
        end;

        { --- phase 1a: listed partitions from MBR/GPT --- }
        Fs_Listed(S, Fsize, Parts);
        for I := 0 to Length(Parts) - 1 do
        begin
            SetLength(WBuf, 1200);
            S.Seek(Parts[I].StartV, soFromBeginning);
            N := S.Read(WBuf[0], 1200);
            H := Raw_BytesToHex(WBuf, N);
            Parts[I].Fs := Fs_Probe_Hex(H);
        end;

        { --- phase 1b: lost partitions via 512-aligned probe --- }
        SetLength(All, 0);
        Off := 0;
        while Off < Fsize do
        begin
            if not Fs_Inside_Listed(Parts, Off) then
            begin
                SetLength(WBuf, 1200);
                S.Seek(Off, soFromBeginning);
                N := S.Read(WBuf[0], 1200);
                if N > 0 then
                begin
                    H := Raw_BytesToHex(WBuf, N);
                    Tok := Fs_Probe_Hex(H);
                    if Tok <> '' then
                    begin
                        Est := Fsize;
                        for I := 0 to Length(Parts) - 1 do
                            if (Parts[I].StartV > Off) and
                               (Parts[I].StartV < Est) then
                                Est := Parts[I].StartV;
                        Rec.StartV := Off;
                        Rec.SizeV := Est - Off;
                        Rec.Fs := Tok;
                        Rec.Listed := False;
                        SetLength(All, Length(All) + 1);
                        All[Length(All) - 1] := Rec;
                    end;
                end;
            end;
            Off := Off + 512;
        end;

        { --- assemble: sort by start, listed first in numbering --- }
        { lost partitions sorted by start }
        for I := 0 to Length(All) - 1 do
            for J := I + 1 to Length(All) - 1 do
                if All[J].StartV < All[I].StartV then
                begin
                    Rec := All[I];
                    All[I] := All[J];
                    All[J] := Rec;
                end;
        { final list: listed (sorted by start), then lost (sorted by start) }
        for I := 0 to Length(Parts) - 1 do
            for J := I + 1 to Length(Parts) - 1 do
                if Parts[J].StartV < Parts[I].StartV then
                begin
                    Rec := Parts[I];
                    Parts[I] := Parts[J];
                    Parts[J] := Rec;
                end;
        Parts2 := Parts;
        for I := 0 to Length(All) - 1 do
        begin
            SetLength(Parts2, Length(Parts2) + 1);
            Parts2[Length(Parts2) - 1] := All[I];
        end;
        Parts := Parts2;
        NParts := Length(Parts);

        { --- report the partition map --- }
        WriteLn('SCAN: ' + FsDevice);
        NList := 0;
        for I := 0 to NParts - 1 do
        begin
            if Parts[I].Listed then
                Inc(NList);
            Tok := Parts[I].Fs;
            if Tok = '' then
                Tok := 'unknown';
            if Parts[I].Listed then
                WriteLn(Format('  part %d: 0x%s %d %d %s listed',
                    [I + 1, LowerCase(IntToHex(Parts[I].StartV, 12)),
                     Parts[I].StartV, Parts[I].SizeV, Tok]))
            else
                WriteLn(Format('  part %d: 0x%s %d ~%d %s lost',
                    [I + 1, LowerCase(IntToHex(Parts[I].StartV, 12)),
                     Parts[I].StartV, Parts[I].SizeV, Tok]));
        end;
        WriteLn(Format('SCAN: %d partitions found (%d listed, %d lost)',
            [NParts, NList, NParts - NList]));

        { --- phase 2: per-partition signature scan (V20 engine) --- }
        if Modus = 'copy' then
            ForceDirectories(TargetDir + '/FS-CARVE');
        SetLength(Block, Raw_Block);
        SetLength(Head, Raw_Block);
        Total := 0;
        Scanned := 0;
        for I := 0 to NParts - 1 do
        begin
            Sel := False;
            for K := 0 to Formats.Count - 1 do
                if (Formats[K] = 'all') or (Formats[K] = Parts[I].Fs) then
                    Sel := True;
            if (Parts[I].Fs = '') or (Parts[I].SizeV <= 0) or not Sel then
                Continue;
            Lo := Parts[I].StartV;
            Hi := Lo + Parts[I].SizeV;
            WriteLn(Format('SCAN-PART %d %s 0x%s %d', [I + 1, Parts[I].Fs,
                LowerCase(IntToHex(Lo, 12)), Parts[I].SizeV]));

            { first pass: collect hits inside [Lo, Hi) }
            SetLength(Hits, 0);
            HitCount := 0;
            SetLength(Carry, 0);
            CarryLen := 0;
            Base := Lo;
            S.Seek(Lo, soFromBeginning);
            while Base < Hi do
            begin
                N := S.Read(Block[0], Raw_Block);
                if N <= 0 then
                    Break;
                SetLength(Window, CarryLen + N);
                if CarryLen > 0 then
                    Move(Carry[0], Window[0], CarryLen);
                Move(Block[0], Window[CarryLen], N);
                H := Raw_BytesToHex(Window, Length(Window));
                BufBase := Base - CarryLen;
                for E := 0 to Length(RawEntries) - 1 do
                begin
                    if RawEntries[E].AnchorHex = '' then
                        Continue;
                    if Length(RawEntries[E].Sig) < 4 then
                        Continue;
                    P := PosEx(RawEntries[E].AnchorHex, H, 1);
                    while P > 0 do
                    begin
                        if (P - 1) mod 2 = 0 then
                        begin
                            SigStart := (P - 1) - RawEntries[E].AnchorNibble;
                            if (SigStart mod 2 = 0) and (SigStart >= 0) then
                                if Raw_SigMatch(H, SigStart + 1, E) then
                                begin
                                    Hit := BufBase + SigStart div 2
                                        - RawEntries[E].Off;
                                    if (Hit >= Lo) and (Hit < Hi) then
                                    begin
                                        Inc(HitCount);
                                        SetLength(Hits, HitCount);
                                        Hits[HitCount - 1].Offset := Hit;
                                        Hits[HitCount - 1].Entry := E;
                                        Hits[HitCount - 1].Size := 0;
                                        Hits[HitCount - 1].Exact := False;
                                    end;
                                end;
                        end;
                        P := PosEx(RawEntries[E].AnchorHex, H, P + 1);
                    end;
                end;
                Base := Base + Raw_Block;
                if Base < Hi then
                begin
                    if Length(Window) > Raw_Carry then
                    begin
                        SetLength(Carry, Raw_Carry);
                        Move(Window[Length(Window) - Raw_Carry],
                            Carry[0], Raw_Carry);
                        CarryLen := Raw_Carry;
                    end
                    else
                    begin
                        SetLength(Carry, Length(Window));
                        if Length(Window) > 0 then
                            Move(Window[0], Carry[0], Length(Window));
                        CarryLen := Length(Window);
                    end;
                end;
            end;

            { sort by (offset, name) - same tie-break as the other editions }
            for J := 0 to HitCount - 1 do
                for K := J + 1 to HitCount - 1 do
                    if (Hits[K].Offset < Hits[J].Offset) or
                       ((Hits[K].Offset = Hits[J].Offset) and
                        (RawEntries[Hits[K].Entry].Name <
                         RawEntries[Hits[J].Entry].Name)) then
                    begin
                        TmpHit := Hits[J];
                        Hits[J] := Hits[K];
                        Hits[K] := TmpHit;
                    end;

            { second pass: carve sizes, broken check, report, carve }
            Count := 0;
            NextVal := Lo;
            for J := 0 to HitCount - 1 do
            begin
                E := Hits[J].Entry;
                if (Pos('filesystem', RawEntries[E].Name) > 0) or
                    (RawEntries[E].Name = 'Linux swap area') then
                    Continue;
                if Hits[J].Offset < NextVal then
                    Continue;
                S.Seek(Hits[J].Offset, soFromBeginning);
                N := S.Read(Head[0], Raw_Block);
                HeadHex := Raw_BytesToHex(Head, N);
                Raw_CarveSize(HeadHex, RawEntries[E].Name, Hits[J].Size,
                    Hits[J].Exact);
                if Hits[J].Exact then
                    NextVal := Hits[J].Offset + Hits[J].Size
                else
                    NextVal := Hits[J].Offset + 1;
                Broken := Fs_Broken(Parts, I, Hits[J].Offset, Hits[J].Size);
                Inc(Count);
                Inc(Total);
                Ext := Raw_FirstExt(RawEntries[E].Exts);
                Write('  hit: 0x' + LowerCase(IntToHex(Hits[J].Offset, 12))
                    + ' ' + IntToStr(Hits[J].Offset) + ' '
                    + RawEntries[E].Name + ' -> ' + Ext
                    + ' (carve ' + IntToStr(Hits[J].Size) + ' bytes');
                if not Hits[J].Exact then
                    Write(', capped');
                if Broken then
                    Write(', broken');
                WriteLn(')');
                if Modus = 'copy' then
                begin
                    OutDir := TargetDir + '/FS-CARVE/p' + IntToStr(I + 1)
                        + '-' + LowerCase(IntToHex(Lo, 12));
                    while True do
                    begin
                        try
                            ForceDirectories(OutDir);
                            OutPath := OutDir + '/'
                                + LowerCase(IntToHex(Hits[J].Offset, 12))
                                + '.' + Ext;
                            Dest := TFileStream.Create(OutPath, fmCreate);
                            try
                                S.Seek(Hits[J].Offset, soFromBeginning);
                                Written := 0;
                                while Written < Hits[J].Size do
                                begin
                                    if Hits[J].Size - Written > Raw_Block then
                                        N := Raw_Block
                                    else
                                        N := Hits[J].Size - Written;
                                    N := S.Read(Head[0], N);
                                    if N <= 0 then
                                        Break;
                                    Dest.Write(Head[0], N);
                                    Written := Written + N;
                                end;
                            finally
                                Dest.Free;
                            end;
                            Break;
                        except
                            on EStreamError do
                            begin
                                WriteLn('SCAN: out of space at ' + OutDir);
                                Write('SCAN: new target directory '
                                    + '(empty = abort): ');
                                Flush(Output);
                                ReadLn(NewT);
                                if NewT = '' then
                                begin
                                    WriteLn('SCAN: copy aborted by user');
                                    Halt(65);
                                end;
                                OutDir := NewT + '/FS-CARVE/p'
                                    + IntToStr(I + 1) + '-'
                                    + LowerCase(IntToHex(Lo, 12));
                            end;
                        end;
                    end;
                    WriteLn('  carved: ' + OutPath);
                    if LogFile <> '' then
                    begin
                        H := '{"action": "carved", "src": "' + FsDevice + '@'
                            + IntToStr(Hits[J].Offset) + '", "dst": "'
                            + OutPath + '", "part": ' + IntToStr(I + 1);
                        if Broken then
                            H := H + ', "broken": true';
                        H := H + '}';
                        Out_Log(H);
                    end;
                end;
            end;
            Inc(Scanned);
            WriteLn(Format('SCAN-PART %d: %d signatures found',
                [I + 1, Count]));
        end;
        WriteLn(Format('SCAN: done, %d signatures in %d partitions',
            [Total, Scanned]));
    finally
        S.Free;
        Formats.Free;
    end;
end;

{ Validate_Options: sanity-check the parsed options }
procedure Validate_Options;
var
    I: Integer;
    LangOK: Boolean;
begin
    LangOK := False;
    for I := Low(LangCodes) to High(LangCodes) do
        if LangCodes[I] = Lang then
            LangOK := True;
    if not LangOK then
    begin
        Out_Err(Tf(Tr('Unsupported language: %s (see --lang)'), [Lang]));
        Lang_List;
        Halt(2);
    end;
    if not ((Modus = 'print') or (Modus = 'copy') or (Modus = 'move')
            or (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred')) then
    begin
        Out_Err(Tf(Tr('Invalid --mode: %s'), [Modus]));
        Halt(2);
    end;
    if (Modus = 'trash') and (not HaveTool('trash-put')) and (not HaveTool('trash')) then
    begin
        Out_Err(Tr('--trash needs trash-put (trash-cli)'));
        Halt(2);
    end;
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err(Tf(Tr('Source directory not found: %s'), [SourceDir]));
        Halt(2);
    end;
end;

{ ------------------------------------------------------------------ }
{ Main                                                                }
{ ------------------------------------------------------------------ }

{ Main: program flow: parse, validate, collect, run, summarize }
procedure Main;
begin
    Parse_Arguments;
    if DoSelfTest then
    begin
        if Self_Test then
            Halt(0)
        else
            Halt(1);
    end;
    Validate_Options;
    if Magic_Mode then
    begin
        Collect_Files;
        Magic_Report_All;
        Halt(0);
    end;
    if RawDevice <> '' then
    begin
        Raw_Scan_Main;
        Halt(0);
    end;
    if FsFormatsArg <> '' then
    begin
        if FsDevice = '' then
        begin
            Out_Err('SCAN: --scan needs a device or image path');
            Halt(64);
        end;
        Fs_Scan_Main;
        Halt(0);
    end;
    Collect_Files;
    if not DoQuiet then
        WriteLn(Tf(Tr('Found %s file(s)'), [IntToStr(Files.Count)]));
    Run_Threads;
    if not DoQuiet then
    begin
        WriteLn('');
        WriteLn('--- ' + Tr('Summary') + ' ---');
        WriteLn(Tf(Tr('Copied : %s'), [IntToStr(CountCopied)]));
        WriteLn(Tf(Tr('Moved  : %s'), [IntToStr(CountMoved)]));
        WriteLn(Tf(Tr('Removed: %s'), [IntToStr(CountRemoved)]));
        WriteLn(Tf(Tr('Trashed  : %s'), [IntToStr(CountTrashed)]));
        WriteLn(Tf(Tr('Shredded : %s'), [IntToStr(CountShredded)]));
        WriteLn(Tf(Tr('Extracted: %s'), [IntToStr(CountExtracted)]));
        WriteLn(Tf(Tr('Preview: %s'), [IntToStr(CountPreview)]));
        WriteLn(Tf(Tr('Skipped: %s'), [IntToStr(CountSkipped)]));
        WriteLn(Tf(Tr('Failed : %s'), [IntToStr(CountFailed)]));
    end;
    if UndoFile <> '' then
    begin
        UndoLines.SaveToFile(UndoFile);
        FpChmod(UndoFile, S_IRUSR or S_IWUSR or S_IXUSR
                          or S_IRGRP or S_IXGRP or S_IROTH or S_IXOTH);
        WriteLn(Tf(Tr('Undo script written: %s'), [UndoFile]));
    end;
end;

var
    Rc: Integer;
begin
    Lang := 'en';
    Modus := 'print';
    DirList := '';
    SubList := '';
    RenameVal := '';
    ExtensionVal := '';
    TypeFilter := '';
    SourceDir := '';
    TargetDir := '.';
    PauseSec := 0;
    LogFile := '';
    UndoFile := '';
    JobCount := 1;
    DoReplace := False;
    DoRecursive := False;
    DoHidden := False;
    DoLinks := False;
    DoColored := False;
    DoQuiet := False;
    DoVerbose := False;
    DoStats := False;
    DoStrip := False;
    DoExif := False;
    DoDecompress := False;
    DoSelfTest := False;
    DecompressDepth := 0;
    CountCopied := 0;
    CountMoved := 0;
    CountRemoved := 0;
    CountTrashed := 0;
    CountShredded := 0;
    CountSkipped := 0;
    CountFailed := 0;
    CountExtracted := 0;
    CountPreview := 0;
    Files := TStringList.Create;
    Lock := TCriticalSection.Create;
    UndoLines := TStringList.Create;
    Randomize;
    try
        Main;
        Rc := 0;
        if CountFailed > 0 then
            Rc := 1;
    finally
        Files.Free;
        Lock.Free;
        UndoLines.Free;
    end;
    WriteLn(ClosingPhrase);
    Halt(Rc);
end.
