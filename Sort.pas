{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{                                                                             }
{  Script  : Sort.pas                                                         }
{  Version : 17.0                                                             }
{  Desc    : Ejder file organizer - FreePascal translation of Sort.sh v17.0   }
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
    SysUtils, Classes, Math, SyncObjs, MD5, SHA1, Zipper, BaseUnix, Process;

const
    ScriptVersion = '17.0';
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
    CompareFile    : string;   { --compare (accepted, not implemented: same as shell V11) }
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
        Out_Err('FAILED) ' + F + ' - could not extract (rc ' + IntToStr(Rc) + ')');
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
        Out_Tagged('PREVIEW', 'EXTRACT(' + IntToStr(CountExtracted) + '): ' + F
                   + ' <=> delete archive');
        Bump(CountPreview);
    end
    else if Modus = 'trash' then
    begin
        Rc := Trash_File(F, Inner);
        if Rc = 0 then
            Bump(CountTrashed)
        else
        begin
            Out_Err('FAILED) trash ' + F);
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
        if Modus = 'remove' then
        begin
            if DeleteFile(F) then
            begin
                Out_Tagged('REMOVED', F);
                Bump(CountRemoved);
                Out_Log('rm ' + F);
            end
            else
            begin
                Out_Err('FAILED) rm ' + F);
                Bump(CountFailed);
            end;
        end
        else if Modus = 'trash' then
        begin
            Rc := Trash_File(F, Tmp);
            if Rc = 0 then
            begin
                Out_Tagged('TRASHED', F);
                Bump(CountTrashed);
            end
            else
            begin
                Out_Err('FAILED) trash ' + F + ' (rc ' + IntToStr(Rc) + ')');
                Bump(CountFailed);
            end;
        end
        else
        begin
            Shred_File(F);
            Out_Tagged('SHREDDED', F);
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
        Out_Err('FAILED) mkdir ' + ExtractFileDir(Target));
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
            Out_Err('FAILED) move ' + F);
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
            Out_Err('FAILED) copy ' + F);
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

{ Show_Version: print the version banner }
procedure Show_Version;
begin
    WriteLn('Sort ', ScriptVersion, ' (FreePascal 3.2.2 translation of Sort.sh)');
end;

{ Show_Usage: print the short usage reminder }
procedure Show_Usage;
begin
    WriteLn('Usage: sort [OPTIONS] [DIR...]');
    WriteLn('Try ''sort --help'' for the full option list.');
end;

{ Show_Help: print the full option help }
procedure Show_Help;
begin
    Show_Version;
    WriteLn('');
    WriteLn('Ejder file organizer - FreePascal translation of Sort.sh v17.0');
    WriteLn('');
    WriteLn('MODES:');
    WriteLn('  --mode=MODE        print (default) / copy / move / remove / trash / shred');
    WriteLn('  --copy --move      shortcuts for --mode=');
    WriteLn('  --remove --delete  shortcut for --mode=remove');
    WriteLn('  --trash --shred    shortcuts for --mode=');
    WriteLn('');
    WriteLn('STRUCTURE:');
    WriteLn('  --dirs=LEVELS      directory levels, comma/plus separated:');
    WriteLn('                     year created modified accessed mime mime-main mime-sub');
    WriteLn('                     mime-ext extension size format md5 sha1 sha256 sha512');
    WriteLn('                     sha random duration camera exifdate title compressed');
    WriteLn('                     folder folder_name (unknown values are used literally)');
    WriteLn('  --subdirs=LEVELS   same values, added below --dirs');
    WriteLn('  --extension=VALUE  none / mime / mime-sub / mime-ext / extension / literal');
    WriteLn('  --rename=VALUE     sha / sha256 / md5 / compressed / title ...');
    WriteLn('  --title            shortcut for --rename=title');
    WriteLn('');
    WriteLn('FILTERS / SCOPE:');
    WriteLn('  --type=VALUE       only files whose MIME contains VALUE');
    WriteLn('  --source=DIR       start point (default: current directory)');
    WriteLn('  --target=DIR       root for the new tree (default: current directory)');
    WriteLn('  --recursive        walk subdirectories (default: non-recursive)');
    WriteLn('  --hidden           include hidden files');
    WriteLn('  --links            include symbolic links');
    WriteLn('');
    WriteLn('ARCHIVES:');
    WriteLn('  --decompress       extract archives first and process the contents');
    WriteLn('  --rename=compressed  rename archive to its main inner directory/file');
    WriteLn('');
    WriteLn('EXTRAS:');
    WriteLn('  --exif             add <Camera>/<Date> levels (needs exiftool)');
    WriteLn('  --strip            strip EXIF from processed files (needs exiftool)');
    WriteLn('  --replace          overwrite existing targets');
    WriteLn('  --jobs=N           parallel workers (default: 1)');
    WriteLn('  --pause=SEC        sleep between files');
    WriteLn('  --log=FILE         append an action log');
    WriteLn('  --undo[=FILE]      write an inverse shell script');
    WriteLn('  --colored          ANSI-colored output');
    WriteLn('  --quiet --verbose --stats');
    WriteLn('  --self-test        run built-in checks');
    WriteLn('  --usage --help --version');
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
            else if K = '--compare' then
                CompareFile := 'yes'
            else if K = '--self-test' then
                DoSelfTest := True
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
                Out_Err('Unknown option: ' + A);
                Show_Usage;
                Halt(2);
            end;
        end
        else
            SourceDir := A;  { positional: start directory }
        I := I + 1;
    end;
end;

{ Validate_Options: sanity-check the parsed options }
procedure Validate_Options;
begin
    if not ((Modus = 'print') or (Modus = 'copy') or (Modus = 'move')
            or (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred')) then
    begin
        Out_Err('Invalid --mode: ' + Modus);
        Halt(2);
    end;
    if (Modus = 'trash') and (not HaveTool('trash-put')) and (not HaveTool('trash')) then
    begin
        Out_Err('--trash needs trash-put (trash-cli) installed');
        Halt(2);
    end;
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err('Source directory not found: ' + SourceDir);
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
    Collect_Files;
    if not DoQuiet then
        WriteLn('Found ' + IntToStr(Files.Count) + ' file(s)');
    Run_Threads;
    if not DoQuiet then
    begin
        WriteLn('');
        WriteLn('--- Summary ---');
        WriteLn('Copied   : ' + IntToStr(CountCopied));
        WriteLn('Moved    : ' + IntToStr(CountMoved));
        WriteLn('Removed  : ' + IntToStr(CountRemoved));
        WriteLn('Trashed  : ' + IntToStr(CountTrashed));
        WriteLn('Shredded : ' + IntToStr(CountShredded));
        WriteLn('Extracted: ' + IntToStr(CountExtracted));
        WriteLn('Preview  : ' + IntToStr(CountPreview));
        WriteLn('Skipped  : ' + IntToStr(CountSkipped));
        WriteLn('Failed   : ' + IntToStr(CountFailed));
    end;
    if UndoFile <> '' then
    begin
        UndoLines.SaveToFile(UndoFile);
        FpChmod(UndoFile, S_IRUSR or S_IWUSR or S_IXUSR
                          or S_IRGRP or S_IXGRP or S_IROTH or S_IXOTH);
        WriteLn('Undo script written: ' + UndoFile);
    end;
end;

var
    Rc: Integer;
begin
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
    CompareFile := '';
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
