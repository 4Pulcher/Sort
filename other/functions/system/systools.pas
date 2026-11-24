{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : systools.pas                                                     }
{  Version : 1.0                                                              }
{  Desc    : System toolkit - external tools, temp dirs, tree removal         }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh systools.pas }
{                                                                             }
{*****************************************************************************}
unit systools;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, Classes, Process, BaseUnix;

{ HaveTool: true when an external tool exists on PATH }
function HaveTool(const Exe: string): Boolean;

{ RunTool: run Exe with Args, capture merged stdout+stderr, return exit code.
  127 = tool missing (same convention as the shell library). }
function RunTool(const Exe: string; const Args: array of string;
                 out Text: string): Integer;

{ Make_Temp_Dir: create a unique temporary directory below TMPDIR or /tmp }
function Make_Temp_Dir: string;

{ Find_All_Files: recursively list every file below a directory }
procedure Find_All_Files(const Dir: string; List: TStringList);

{ Remove_Tree: delete a whole directory tree }
procedure Remove_Tree(const Dir: string);

implementation

function HaveTool(const Exe: string): Boolean;
begin
    if Pos(PathSep, Exe) > 0 then
        Result := FileExists(Exe)
    else
        Result := FileSearch(Exe, GetEnvironmentVariable('PATH')) <> '';
end;

function RunTool(const Exe: string; const Args: array of string;
                 out Text: string): Integer;
var
    P  : TProcess;
    Buf: string;
    N  : LongInt;
    I  : Integer;
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

procedure Find_All_Files(const Dir: string; List: TStringList);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    Rc := FindFirst(IncludeTrailingPathDelimiter(Dir) + AllFilesMask,
                    faAnyFile, SR);
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

procedure Remove_Tree(const Dir: string);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    Rc := FindFirst(IncludeTrailingPathDelimiter(Dir) + AllFilesMask,
                    faAnyFile, SR);
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

end.
