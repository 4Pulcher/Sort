{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : filetools.pas                                                    }
{  Version : 1.0                                                              }
{  Desc    : File toolkit - size, links, copy/move/shred/trash, extensions    }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh filetools.pas }
{                                                                             }
{*****************************************************************************}
unit filetools;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, Classes, Math, BaseUnix, systools;

{ Is_Symlink: true when the path is a symbolic link }
function Is_Symlink(const F: string): Boolean;

{ Get_File_Size: file size in bytes (stat) }
function Get_File_Size(const F: string): Int64;

{ Copy_File: copy a file byte by byte (TFileStream) }
function Copy_File(const Src, Dst: string): Boolean;

{ Move_File: move a file: rename, or copy+delete across devices }
function Move_File(const Src, Dst: string): Boolean;

{ Shred_File: overwrite a file with random bytes, then delete it }
procedure Shred_File(const F: string);

{ Trash_File: move a file to the trash (trash-put / trash) }
function Trash_File(const F: string; out Text: string): Integer;

{ Get_File_Ext: last-dot extension, without the dot }
function Get_File_Ext(const F: string): string;

{ Name_Without_Ext: name without ANY extension (last-dot variant) }
function Name_Without_Ext(const F: string): string;

{ Get_Compound_Ext: dotted suffixes like .tar.gz count as ONE extension.
  Returns True and Suffix without the leading dot, e.g. 'tar.gz'. }
function Get_Compound_Ext(const F: string; out Suffix: string): Boolean;

{ Get_Base_Name: name without ANY extension - a compound suffix counts as one }
function Get_Base_Name(const F: string): string;

{ File_Time: modified/created/accessed time of a file as TDateTime }
function File_Time(const F, Which: string): TDateTime;

{ First_Token: first space-separated token of a string }
function First_Token(const S: string): string;

implementation

function Is_Symlink(const F: string): Boolean;
var
    SB: TStat;
begin
    Result := False;
    if FpLStat(F, SB) = 0 then
        Result := FPS_ISLNK(SB.st_mode);
end;

function Get_File_Size(const F: string): Int64;
var
    SB: TStat;
begin
    Result := 0;
    if FpStat(F, SB) = 0 then
        Result := SB.st_size;
end;

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

procedure Shred_File(const F: string);
var
    FS  : TFileStream;
    Buf : array[1..4096] of Byte;
    Left: Int64;
    I   : Integer;
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

function Trash_File(const F: string; out Text: string): Integer;
begin
    if HaveTool('trash-put') then
        Result := RunTool('trash-put', [F], Text)
    else if HaveTool('trash') then
        Result := RunTool('trash', [F], Text)
    else
        Result := 127;
end;

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
        if Length(LBase) > Length(Comps[I]) then
            if Copy(LBase, Length(LBase) - Length(Comps[I]) + 1,
                    Length(Comps[I])) = Comps[I] then
            begin
                Suffix := Copy(Base, Length(Base) - Length(Comps[I]) + 2, MaxInt);
                Result := True;
                Exit;
            end;
end;

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

function File_Time(const F, Which: string): TDateTime;
var
    SB: TStat;
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
        if FpStat(F, SB) = 0 then
            Result := UnixToDateTime(SB.st_mtime);
    end;
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

end.
