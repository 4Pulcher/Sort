{*******************************************************************************}
{  NB/This code is not tested yet!                                             }
{                                                                              }
{  Script  : Sort-V2.5.pas                                                     }
{  Version : 2.5                                                               }
{  Desc    : Prototype micro script (extension sorter)                         }
{            FreePascal translation of Sort.sh v2.5                            }
{  Author  : HEjder                                                            }
{                                                                              }
{  Translated to FreePascal 3.2.2 (mode objfpc, H+).                           }
{  Compile with:  fpc -Mobjfpc -Sh Sort-V2.5.pas                               }
{                                                                              }
{  Native FreePascal libraries used:                                           }
{    - SysUtils, Classes          : RTL / FCL                                  }
{    - Process (TProcess)         : FCL (file(1) for MIME detection)           }
{*******************************************************************************}
{$MODE OBJFPC}{$H+}
program SortV2_5;

uses
    SysUtils, Classes, Process;

const
    ScriptVersion = '2.5';
    ClosingPhrase = 'Thanks for using HEjder scripts!';

var
    CountMoved : Integer;
    CountFailed: Integer;


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
    C := C + 1;
end;

{ ------------------------------------------------------------------ }
{ MIME helpers                                                        }
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

{ Name without ANY extension }
function Name_Without_Ext(const F: string): string;
var
    Dot: Integer;
begin
    Dot := LastDelimiter('.', F);
    if Dot > 1 then
        Result := Copy(F, 1, Dot - 1)
    else
        Result := F;
end;

{ ------------------------------------------------------------------ }
{ File operations                                                     }
{ ------------------------------------------------------------------ }

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

{ ------------------------------------------------------------------ }
{ Extension sorter                                                    }
{ ------------------------------------------------------------------ }

{ Recursive walk: every file moves to <UPPER-MIME-SUB>/<flattened path> }
procedure Sort_Extension(const P: string);
var
    SR: TSearchRec;
    Rc: Integer;
    Full, Short, Name, Mime, Ext, Dir, Target: string;
begin
    if DirectoryExists(P) then
    begin
        Rc := FindFirst(IncludeTrailingPathDelimiter(P) + AllFilesMask, faAnyFile, SR);
        try
            while Rc = 0 do
            begin
                Full := IncludeTrailingPathDelimiter(P) + SR.Name;
                if (SR.Name <> '.') and (SR.Name <> '..') then
                    Sort_Extension(Full);
                Rc := FindNext(SR);
            end;
        finally
            FindClose(SR);
        end;
    end
    else if FileExists(P) then
    begin
        Short := P;
        if Copy(Short, 1, 2) = './' then
            Short := Copy(Short, 3, MaxInt);
        Name := StringReplace(Short, '/', '~', [rfReplaceAll]);
        Name := Name_Without_Ext(Name);
        Mime := Detect_MIME(P);
        Ext := MIME_Sub(Mime);
        if Ext <> '' then
            Dir := UpCase(Ext)
        else
            Dir := '?';
        if not ForceDirectories(Dir) then
        begin
            Out_Err('FAILED) mkdir ' + Dir);
            Bump(CountFailed);
            Exit;
        end;
        { the whole relative path is flattened into the file name }
        Target := Dir + '/' + Name + '.' + LowerCase(Ext);
        if Move_File(P, Target) then
        begin
            Out_Tagged('MOVED', P + ' -> ' + Target);
            Bump(CountMoved);
        end
        else
        begin
            Out_Err('FAILED) mv ' + P);
            Bump(CountFailed);
        end;
    end
    else
        Out_Err('Error: ' + P + ' (does not exist!)');
end;

{ ------------------------------------------------------------------ }
{ Main                                                                }
{ ------------------------------------------------------------------ }

{ Main: program flow: parse, validate, collect, run, summarize }
procedure Main;
var
    I: Integer;
begin
    if ParamCount > 0 then
    begin
        WriteLn('Sorting..');
        for I := 1 to ParamCount do
            Sort_Extension(ParamStr(I));
        WriteLn('Done!');
        WriteLn('');
        WriteLn('--- Summary ---');
        WriteLn('Moved  : ' + IntToStr(CountMoved));
        WriteLn('Failed : ' + IntToStr(CountFailed));
    end;
end;

var
    Rc: Integer;
begin
    CountMoved := 0;
    CountFailed := 0;
    if not HaveTool('file') then
    begin
        WriteLn(StdErr, 'Binary ''file'' not found!');
        Halt(1);
    end;
    try
        Main;
        Rc := 0;
        if CountFailed > 0 then
            Rc := 1;
    except
        Rc := 1;
    end;
    WriteLn(ClosingPhrase);
    Halt(Rc);
end.