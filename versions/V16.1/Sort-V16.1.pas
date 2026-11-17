{*******************************************************************************}
{  Script  : Sort-V16.1.pas                                                    }
{  Version : 16.1                                                              }
{  Desc    : Ejder file organizer - FreePascal translation of Sort.sh v16.1    }
{  Author  : HEjder                                                            }
{                                                                              }
{  Translated to FreePascal 3.2.2 (mode objfpc, H+).                           }
{  Compile with:  fpc -Mobjfpc -Sh Sort-V16.1.pas                              }
{                                                                              }
{  Native FreePascal libraries used:                                           }
{    - SysUtils, Classes            : RTL / FCL                                }
{    - Math, SyncObjs               : FCL (thread pool locking)                }
{    - Process (TProcess)           : FCL (external tools)                     }
{                                                                              }
{  NOTE: FPC has no native SHA256/SHA512 unit (packages/hash only              }
{  ships md5 and sha1), so those fall back to the external tools               }
{  the shell version used (sha256sum / sha512sum).                             }
{*******************************************************************************}
{$MODE OBJFPC}{$H+}
program SortV16_1;

uses
    SysUtils, Classes, Math, SyncObjs, Process;

const
    ScriptVersion = '16.1';
    ClosingPhrase = 'Thanks for using HEjder scripts!';

type
    TSortThread = class(TThread)
    protected
        procedure Execute; override;
    end;

var
    Modus          : string; { print/copy/move/remove/trash/shred }
    RenameVal      : string; { --rename=VALUE }
    ExtensionVal   : string; { --extension=VALUE }
    SourceDir      : string; { start directory }
    TargetDir      : string; { root of the new tree }
    JobCount       : Integer; { --jobs=N }
    DoRecursive    : Boolean; { walk subdirectories }
    DoReplace      : Boolean; { overwrite existing targets }
    DoQuiet        : Boolean; { quiet }
    DoVerbose      : Boolean; { verbose }
    DoStrip        : Boolean; { strip EXIF }
    DoExif         : Boolean; { add camera/date levels }
    Files          : TStringList; { collected files }
    NextIdx        : Integer; { next work item }
    Lock           : TCriticalSection; { thread lock }
    CountCopied    : Integer;
    CountMoved     : Integer;
    CountRemoved   : Integer;
    CountTrashed   : Integer;
    CountShredded  : Integer;
    CountSkipped   : Integer;
    CountFailed    : Integer;
    CountPreview   : Integer;


{ Out_Tagged: print a tagged line (thread-safe) }
procedure Out_Tagged(const Tag, S: string);
begin
    WriteLn(Tag + ' ' + S);
end;

{ Out_Err: print an error line to stderr }
procedure Out_Err(const S: string);
begin
    WriteLn(StdErr, S);
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

{ Name without ANY extension }
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

{ Get_Base_Name: name without extension }
function Get_Base_Name(const F: string): string;
begin
    Result := Name_Without_Ext(F);
end;

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
    if Algo = 'sha256' then
        begin
        if RunTool('sha256sum', [F], Res) = 0 then
            Result := First_Token(Trim(Res));
    end
    else if Algo = 'sha512' then
        begin
        if RunTool('sha512sum', [F], Res) = 0 then
            Result := First_Token(Trim(Res));
    end
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
                    List.Add(Full);
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
    if Value = 'camera' then
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
    if Value = 'extension' then
        Text := Get_File_Ext(F)
    if Value = 'mime' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := Mime;
    end
    else if Value = 'mime-sub' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := MIME_Sub(Mime);
    end
    else if Value = 'random' then
        Text := IntToStr(Random(100000))
    else if (Value = 'title') or (Value = 'long') or (Value = 'short') then
    begin
        Text := Exif_Field(F, 'Title');
        if Text = '' then
            Text := Get_Base_Name(F);
        Text := Underscore(Text);
    end
    else
        Result := 2;  { unknown -> treated as literal }
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
        end;
    finally
        Parts.Free;
    end;
end;

{ Compute the new path for file F }
function Build_Name(const F: string): string;
var
    Dirs, Subs: TStringList;
    NewDir, NewName, Ext, Suffix: string;
    I: Integer;
begin
    Dirs := TStringList.Create;
    Subs := TStringList.Create;
    try


        { base name }
        else if RenameVal = 'random' then
            NewName := IntToStr(Random(100000))
        else if (RenameVal = 'title') or (RenameVal = 'long') or (RenameVal = 'short') then
        begin
            NewName := Exif_Field(F, 'Title');
            if NewName = '' then
                NewName := Get_Base_Name(F);
            NewName := Underscore(NewName);
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
        else if ExtensionVal = 'extension' then
            Ext := '.' + Get_File_Ext(F)
        else if ExtensionVal = '' then
        begin
            if Get_File_Ext(F) <> '' then
                Ext := '.' + Get_File_Ext(F)
            else
                Ext := '';
        end
        else
            Ext := '.' + ExtensionVal;

        if DoExif then
            Build_Segments('camera+exifdate', F, Subs);

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

{ Process_File: process one file according to the active mode }
procedure Process_File(const F: string);
var
    Target, Tmp: string;
    Rc: Integer;
begin
    Target := Build_Name(F);
    Target := Unique_Target(Target);

    { dry-run: only show the computed target }
    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', F + ' -> ' + Target);
        Bump(CountPreview);
        Exit;
    end;

    { create the target directory, then copy or move }
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

        end
        else
        begin
            Out_Err('FAILED) copy ' + F);
            Bump(CountFailed);
        end;
    end;

    if DoStrip and HaveTool('exiftool') then
        RunTool('exiftool', ['-all=', '-overwrite_original', Target], Tmp);

end;

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

{ Show_Version: print the version banner }
procedure Show_Version;
begin
    WriteLn('Sort ', ScriptVersion, ' (FreePascal 3.2.2 translation of Sort.sh)');
end;

{ Show_Usage: print the short usage reminder }
procedure Show_Usage;
begin
    WriteLn('Usage: sort [OPTIONS] [DIR]');
    WriteLn('Try ''sort --help'' for the full option list.');
end;

{ Show_Help: print the full option help }
procedure Show_Help;
begin
    Show_Version;
    WriteLn('');
    WriteLn('Ejder file organizer - FreePascal translation of Sort-V16.1.sh');
    WriteLn('');
    WriteLn('MODES:');
    WriteLn('  --copy          copy files');
    WriteLn('  --move          move files');
    WriteLn('');
    WriteLn('STRUCTURE:');
    WriteLn('  --rename=VALUE       rename mode: extension long none random short title');
    WriteLn('  --extension=VALUE     extension mode: none/mime/mime-sub/mime-ext/literal');
    WriteLn('');
    WriteLn('EXTRAS:');
    WriteLn('  --jobs=N          parallel workers');
    WriteLn('  --quiet         quiet');
    WriteLn('');
    WriteLn('  --usage --help --version');
end;

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
    { walk the command line: every --word sets an option,
      a bare word is the start directory }
    I := 1;
    while I <= ParamCount do
    begin
        A := ParamStr(I);
        if Copy(A, 1, 2) = '--' then
        begin
            K := LowerCase(A);
            if Pos('=', A) > 0 then
                K := LowerCase(Copy(A, 1, Pos('=', A) - 1));
            if K = '--rename' then
                RenameVal := LowerCase(Opt_Value(A))
            else if K = '--extension' then
                ExtensionVal := LowerCase(Opt_Value(A))
            else if K = '--jobs' then
                JobCount := StrToIntDef(Opt_Value(A), 1)
            else if K = '--copy' then
                Modus := 'copy'
            else if K = '--move' then
                Modus := 'move'
            else if K = '--replace' then
                DoReplace := True
            else if K = '--quiet' then
                DoQuiet := True
            else if K = '--strip' then
                DoStrip := True
            else if K = '--exif' then
                DoExif := True
            else if K = '--usage' then
                begin Show_Usage; Halt(0); end
            else if (K = '--help') or (K = '-h') then
                begin Show_Help; Halt(0); end
            else if K = '--version' then
                begin Show_Version; Halt(0); end
            else
                        begin Out_Err('Unknown option: ' + A); Show_Usage; Halt(2); end
        end
        else
            SourceDir := A;  { positional: start directory }
        I := I + 1;
    end;
end;
{ Validate_Options: sanity-check the parsed options }
procedure Validate_Options;
begin
    if not ((Modus = 'print') or (Modus = 'copy') or (Modus = 'move')) then
    begin
        Out_Err('Invalid --mode: ' + Modus);
        Halt(2);
    end;
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err('Source directory not found: ' + SourceDir);
        Halt(2);
    end;
end;
{ Main: program flow: parse, validate, collect, run, summarize }
procedure Main;
begin
    Parse_Arguments;
    { validate the options before touching anything }
    Validate_Options;
    { collect the complete work list up front }
    Collect_Files;
    if not DoQuiet then
        WriteLn('Found ' + IntToStr(Files.Count) + ' file(s)');
    { process the work list }
    Run_Threads;
    { summary }
    if not DoQuiet then
    begin
        WriteLn('');
        WriteLn('--- Summary ---');
        WriteLn('Copied   : ' + IntToStr(CountCopied));
        WriteLn('Moved    : ' + IntToStr(CountMoved));
        WriteLn('Preview  : ' + IntToStr(CountPreview));
        WriteLn('Failed   : ' + IntToStr(CountFailed));
    end;
end;
var
    Rc: Integer;
begin
    Modus := 'print';
    RenameVal := '';
    ExtensionVal := '';
    SourceDir := '';
    TargetDir := '.';
    JobCount := 1;
    DoReplace := False;
    DoQuiet := False;
    DoVerbose := False;
    DoStrip := False;
    DoExif := False;
    CountCopied := 0;
    CountMoved := 0;
    CountRemoved := 0;
    CountTrashed := 0;
    CountShredded := 0;
    CountSkipped := 0;
    CountFailed := 0;
    CountPreview := 0;
    Files := TStringList.Create;
    NextIdx := 0;
    Lock := TCriticalSection.Create;
    { seed the random generator (--rename=random) }
    Randomize;
    { run the program, then always clean up }
    try
        Main;
        Rc := 0;
        if CountFailed > 0 then
            Rc := 1;
    finally
        Files.Free;
        Lock.Free;
    end;
    WriteLn(ClosingPhrase);
    Halt(Rc);
end.