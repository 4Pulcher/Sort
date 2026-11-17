{*******************************************************************************}
{  Script  : Sort-V15.0.pas                                                    }
{  Version : 15.0                                                              }
{  Desc    : Ejder file organizer - FreePascal translation of Sort.sh v15.0    }
{  Author  : HEjder                                                            }
{                                                                              }
{  Translated to FreePascal 3.2.2 (mode objfpc, H+).                           }
{  Compile with:  fpc -Mobjfpc -Sh Sort-V15.0.pas                              }
{                                                                              }
{  Native FreePascal libraries used:                                           }
{    - SysUtils, Classes            : RTL / FCL                                }
{    - Process (TProcess)           : FCL (external tools)                     }
{                                                                              }
{  NOTE: FPC has no native SHA256/SHA512 unit (packages/hash only              }
{  ships md5 and sha1), so those fall back to the external tools               }
{  the shell version used (sha256sum / sha512sum).                             }
{*******************************************************************************}
{$MODE OBJFPC}{$H+}
program SortV15_0;

uses
    SysUtils, Classes, Process;

const
    ScriptVersion = '15.0';
    ClosingPhrase = 'Thanks for using HEjder scripts!';

var
    Modus          : string; { print/copy/move/remove/trash/shred }
    RenameVal      : string; { --rename=VALUE }
    SourceDir      : string; { start directory }
    TargetDir      : string; { root of the new tree }
    DoRecursive    : Boolean; { walk subdirectories }
    DoQuiet        : Boolean; { quiet }
    DoVerbose      : Boolean; { verbose }
    Files          : TStringList; { collected files }
    CountCopied    : Integer;
    CountMoved     : Integer;
    CountRemoved   : Integer;
    CountTrashed   : Integer;
    CountShredded  : Integer;
    CountSkipped   : Integer;
    CountFailed    : Integer;
    CountPreview   : Integer;


procedure Out_Tagged(const Tag, S: string);
begin
    WriteLn(Tag + ' ' + S);
end;

procedure Out_Err(const S: string);
begin
    WriteLn(StdErr, S);
end;

procedure Bump(var C: Integer);
begin
    C := C + 1;
end;

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

function Get_Base_Name(const F: string): string;
begin
    Result := Name_Without_Ext(F);
end;

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
    if Value = 'extension' then
        Text := Get_File_Ext(F)
    if Value = 'mime' then
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
    else if Value = 'random' then
        Text := IntToStr(Random(100000))
    else if Value = 'sha' then
    begin
        Text := Hash_File(F, 'sha256');
        if Text = '' then
            Exit(1);
    end
    else if Value = 'sha256' then
    begin
        Text := Hash_File(F, 'sha256');
        if Text = '' then
            Exit(1);
    end
    else if Value = 'sha512' then
    begin
        Text := Hash_File(F, 'sha512');
        if Text = '' then
            Exit(1);
    end
    else
        Result := 2;  { unknown -> treated as literal }
end;

function Sanitize_Name(const S: string): string;
var
    I: Integer;
begin
    Result := S;
    for I := 1 to Length(Result) do
        if CharInSet(Result[I], ['/', '\', ':', '*', '?', '"', '<', '>', '|']) then
            Result[I] := '_';
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
        else if RenameVal = 'random' then
            NewName := IntToStr(Random(100000))
        else
            NewName := Get_Base_Name(F);

        { extension }
        if Get_File_Ext(F) <> '' then
            Ext := '.' + Get_File_Ext(F)
        else
            Ext := '';

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

procedure Process_File(const F: string);
var
    Target, Tmp: string;
    Rc: Integer;
begin
    Target := Build_Name(F);
    Target := Unique_Target(Target);

    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', F + ' -> ' + Target);
        Bump(CountPreview);
        Exit;
    end;
end;

procedure Run_Threads;
var
    I: Integer;
begin
    for I := 0 to Files.Count - 1 do
        Process_File(Files[I]);
end;

procedure Show_Version;
begin
    WriteLn('Sort ', ScriptVersion, ' (FreePascal 3.2.2 translation of Sort.sh)');
end;

procedure Show_Usage;
begin
    WriteLn('Usage: sort [OPTIONS] [DIR]');
    WriteLn('Try ''sort --help'' for the full option list.');
end;


function Opt_Value(const Arg: string): string;
begin
    Result := Copy(Arg, Pos('=', Arg) + 1, MaxInt);
end;


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
            else
                        begin Out_Err('Unknown option: ' + A); Show_Usage; Halt(2); end
        end
        else
            SourceDir := A;  { positional: start directory }
        I := I + 1;
    end;
end;
procedure Validate_Options;
begin
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err('Source directory not found: ' + SourceDir);
        Halt(2);
    end;
end;
procedure Main;
begin
    Parse_Arguments;
    Validate_Options;
    Collect_Files;
    WriteLn('Found ' + IntToStr(Files.Count) + ' file(s)');
    Run_Threads;
    WriteLn('');
    WriteLn('--- Summary ---');
    WriteLn('Preview  : ' + IntToStr(CountPreview));
    WriteLn('Failed   : ' + IntToStr(CountFailed));
end;
var
    Rc: Integer;
begin
    Modus := 'print';
    RenameVal := '';
    SourceDir := '';
    TargetDir := '.';
    DoQuiet := False;
    DoVerbose := False;
    CountCopied := 0;
    CountMoved := 0;
    CountRemoved := 0;
    CountTrashed := 0;
    CountShredded := 0;
    CountSkipped := 0;
    CountFailed := 0;
    CountPreview := 0;
    Files := TStringList.Create;
    Randomize;
    try
        Main;
        Rc := 0;
        if CountFailed > 0 then
            Rc := 1;
    finally
        Files.Free;
    end;
    WriteLn(ClosingPhrase);
    Halt(Rc);
end.