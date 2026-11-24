{*******************************************************************************}
{  NB/This code is not tested yet!                                             }
{                                                                              }
{  Script  : Sort-V1.1.pas                                                     }
{  Version : 1.1                                                               }
{  Desc    : Ejder file organizer (first generation)                           }
{            FreePascal translation of Sort.sh v1.1                            }
{  Author  : HEjder                                                            }
{                                                                              }
{  Translated to FreePascal 3.2.2 (mode objfpc, H+).                           }
{  Compile with:  fpc -Mobjfpc -Sh Sort-V1.1.pas                               }
{                                                                              }
{  Native FreePascal libraries used:                                           }
{    - SysUtils, Classes          : RTL / FCL                                  }
{    - Process (TProcess)         : FCL (file, identify, sha256sum)            }
{                                                                              }
{  NOTE: SHA-256 has no native FPC unit (packages/hash only ships              }
{  md5 and sha1), so the sha256sum tool is used, exactly like the              }
{  shell version did.                                                          }
{*******************************************************************************}
{$MODE OBJFPC}{$H+}
program SortV1_1;

uses
    SysUtils, Classes, Process;

const
    ScriptVersion = '1.1';
    ClosingPhrase = 'Thanks for using HEjder scripts!';

var
    Mode        : string;         { Replace / Move / Copy / Add / '' = print }
    DoRename    : Boolean;        { rename files to their SHA-256 sum }
    DoSubDirs   : Boolean;        { recurse into subdirectories }
    DoClasses   : Boolean;        { add TYPE/EXT directory levels }
    DoSizes     : Boolean;        { add image size classes (needs identify) }
    MimeTypes   : TStringList;    { /etc/mime.types cache }
    CountMoved  : Integer;
    CountCopied : Integer;
    CountPreview: Integer;
    CountFailed : Integer;


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

{ Extension for a MIME type from /etc/mime.types (first listed one) }
function Ext_From_MimeTypes(const Mime: string): string;
var
    I: Integer;
    Line, Key: string;
begin
    Result := '';
    if MimeTypes = nil then
        Exit;
    for I := 0 to MimeTypes.Count - 1 do
    begin
        Line := Trim(MimeTypes[I]);
        if (Line = '') or (Line[1] = '#') then
            Continue;
        Key := Copy(Line, 1, Pos(' ', Line + ' ') - 1);
        if Key = Mime then
        begin
            Line := Trim(Copy(Line, Length(Key) + 1, MaxInt));
            if Pos(' ', Line) > 0 then
                Line := Copy(Line, 1, Pos(' ', Line) - 1);
            Result := Line;
            Exit;
        end;
    end;
end;

{ ------------------------------------------------------------------ }
{ Hash / image helpers                                                }
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

{ SHA-256 has no native FPC unit -> external sha256sum, as in the shell }
function Hash_File(const F: string): string;
var
    Res: string;
begin
    Result := '';
    if RunTool('sha256sum', ['-b', F], Res) = 0 then
        Result := First_Token(Trim(Res));
end;

{ Image_WxH: image width and height via identify }
procedure Image_WxH(const F: string; out W, H: Integer);
var
    Res: string;
    P: Integer;
begin
    W := 0;
    H := 0;
    if RunTool('identify', ['-format', '%w:%h', F], Res) <> 0 then
        Exit;
    Res := Trim(Res);
    if Length(Res) < 3 then
        Res := '0:0';
    P := Pos(':', Res);
    if P = 0 then
        Exit;
    W := StrToIntDef(Copy(Res, 1, P - 1), 0);
    H := StrToIntDef(Copy(Res, P + 1, MaxInt), 0);
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
{ Target naming                                                       }
{ ------------------------------------------------------------------ }

{ Target path; N > 0 inserts the ~N collision suffix }
function Target_Path(const Dir, Name, Ext: string; N: Integer): string;
begin
    if N > 0 then
        Result := Dir + '/' + Name + '~' + IntToStr(N)
    else
        Result := Dir + '/' + Name;
    if Ext <> '' then
        Result := Result + '.' + Ext;
end;

{ First free target: base name if free, else ~(N) style ~1, ~2, ... }
function Next_Free(const Dir, Name, Ext: string): string;
var
    N: Integer;
begin
    N := 0;
    Result := Target_Path(Dir, Name, Ext, N);
    while FileExists(Result) do
    begin
        N := N + 1;
        Result := Target_Path(Dir, Name, Ext, N);
    end;
end;

{ ------------------------------------------------------------------ }
{ File processing                                                     }
{ ------------------------------------------------------------------ }

{ Process_File: process one file according to the active mode }
procedure Process_File(const F: string);
var
    Mime, Type_, Ext, Fext, Name, Dir, New, Sub, Class_: string;
    W, H: Integer;
begin
    Mime := Detect_MIME(F);
    if Mime = '' then
    begin
        Out_Err('File (' + F + ') not recognized!');
        Bump(CountFailed);
        Exit;
    end;
    Type_ := UpCase(MIME_Main(Mime));
    Ext := UpCase(MIME_Sub(Mime));
    Fext := Ext_From_MimeTypes(Mime);
    Out_Tagged('MIME', UpCase(Mime) + ' <' + Fext + '>');
    if DoRename then
    begin
        Name := Hash_File(F);
        if Name = '' then
            Name := ExtractFileName(F);
    end
    else
        Name := ExtractFileName(F);
    if DoClasses then
        Dir := Type_ + '/' + Ext
    else
        Dir := Ext;
    if (Type_ = 'IMAGE') and DoSizes then
    begin
        Image_WxH(F, W, H);
        if (W > 0) and (H > 0) then
        begin
            if W > H then
                Sub := 'wide'
            else if W < H then
                Sub := 'high'
            else
                Sub := 'square';
            if (W < 500) or (H < 500) then
                Class_ := 'small-' + Sub
            else if (W > 5000) or (H > 5000) then
                Class_ := 'big-' + Sub
            else
                Class_ := 'medium-' + Sub;
            Dir := Dir + '/' + Class_ + '/' + IntToStr(W) + '-' + IntToStr(H);
        end;
    end;
    { the early eras used ALL-CAPS directory names }
    Dir := UpCase(Dir);
    New := Target_Path(Dir, Name, Fext, 0);
    if (F = New) or (ExpandFileName(F) = ExpandFileName(New)) then
    begin
        Out_Tagged('Equals', New);
        Exit;
    end;
    if Mode = '' then
    begin
        Out_Tagged('Target', New);
        Bump(CountPreview);
        Exit;
    end;
    if (Mode = 'Move') or (Mode = 'Add') then
        New := Next_Free(Dir, Name, Fext);
    if not ForceDirectories(Dir) then
    begin
        Out_Err('FAILED) mkdir ' + Dir);
        Bump(CountFailed);
        Exit;
    end;
    if (Mode = 'Replace') or (Mode = 'Move') then
    begin
        if Move_File(F, New) then
        begin
            Out_Tagged('MOVED', F + ' -> ' + New);
            Bump(CountMoved);
        end
        else
        begin
            Out_Err('FAILED) mv ' + F);
            Bump(CountFailed);
        end;
    end
    else if (Mode = 'Copy') or (Mode = 'Add') then
    begin
        if Copy_File(F, New) then
        begin
            Out_Tagged('COPIED', F + ' -> ' + New);
            Bump(CountCopied);
        end
        else
        begin
            Out_Err('FAILED) cp ' + F);
            Bump(CountFailed);
        end;
    end;
end;

{ Walk one command line item: mode words set the mode, directories are
  recursed into (lost+found skipped unless SubDirs), files are sorted. }
procedure Process_Path(const P: string);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    if DirectoryExists(P) then
    begin
        if (Pos('lost+found', P) > 0) and (not DoSubDirs) then
        begin
            Out_Tagged('DIR', P + ' (skipped)');
            Exit;
        end;
        Out_Tagged('DIR', P);
        Rc := FindFirst(IncludeTrailingPathDelimiter(P) + AllFilesMask, faAnyFile, SR);
        try
            while Rc = 0 do
            begin
                Full := IncludeTrailingPathDelimiter(P) + SR.Name;
                if (SR.Name <> '.') and (SR.Name <> '..') then
                    Process_Path(Full);
                Rc := FindNext(SR);
            end;
        finally
            FindClose(SR);
        end;
    end
    else if FileExists(P) then
    begin
        Out_Tagged('FILE', P);
        Process_File(P);
    end
    else
        Out_Err('File (' + P + ') not recognized!');
end;

{ One command line word: mode word, toggle word, or a file/dir path }
procedure Parse_Item(const A: string);
var
    W: string;
begin
    W := LowerCase(A);
    if (W = 'replace') or (W = 'move') or (W = 'copy') or (W = 'add') then
    begin
        Mode := UpCase(W[1]) + Copy(W, 2, MaxInt);
        Out_Tagged('SET', 'Mode=' + Mode);
    end
    else if W = 'rename' then
    begin
        DoRename := True;
        Out_Tagged('SET', 'Rename=Yes');
    end
    else if W = 'subdirs' then
    begin
        DoSubDirs := True;
        Out_Tagged('SET', 'SubDirs=Yes');
    end
    else if W = 'classes' then
    begin
        DoClasses := True;
        Out_Tagged('SET', 'Classes=Yes');
    end
    else if W = 'sizes' then
    begin
        DoSizes := True;
        Out_Tagged('SET', 'Sizes=Yes');
    end
    else
        Process_Path(A);
end;

{ ------------------------------------------------------------------ }
{ Main                                                                }
{ ------------------------------------------------------------------ }

{ Main: program flow: parse, validate, collect, run, summarize }
procedure Main;
var
    I: Integer;
begin
    if ParamCount = 0 then
    begin
        WriteLn(ExtractFileName(ParamStr(0)));
        WriteLn('');
        WriteLn('Usage: [''Replace''|''Move''|''Copy''|''Add''] [''Rename''] [''SubDirs'']');
        WriteLn('       [''Classes''] [''Sizes''] ''FileList''');
        Exit;
    end;
    Out_Tagged('SCRIPT', ExtractFileName(ParamStr(0)));
    for I := 1 to ParamCount do
        Parse_Item(ParamStr(I));
    WriteLn('');
    WriteLn('--- Summary ---');
    WriteLn('Moved   : ' + IntToStr(CountMoved));
    WriteLn('Copied  : ' + IntToStr(CountCopied));
    WriteLn('Preview : ' + IntToStr(CountPreview));
    WriteLn('Failed  : ' + IntToStr(CountFailed));
end;

var
    Rc: Integer;
begin
    Mode := '';
    DoRename := False;
    DoSubDirs := False;
    DoClasses := False;
    DoSizes := False;
    CountMoved := 0;
    CountCopied := 0;
    CountPreview := 0;
    CountFailed := 0;
    MimeTypes := TStringList.Create;
    if FileExists('/etc/mime.types') then
        MimeTypes.LoadFromFile('/etc/mime.types');
    try
        Main;
        Rc := 0;
        if CountFailed > 0 then
            Rc := 1;
    finally
        MimeTypes.Free;
    end;
    WriteLn(ClosingPhrase);
    Halt(Rc);
end.