{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : compression.pas                                                  }
{  Version : 1.0                                                              }
{  Desc    : Archive toolkit - zip native (Zipper), tar/7z/rar/gz/bz2/xz/zst  }
{            via external tools                                               }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh compression.pas }
{                                                                             }
{*****************************************************************************}
unit compression;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, Classes, Zipper, systools, filetools;

{ Is_Zip_File: true when the file starts with the PK zip magic }
function Is_Zip_File(const F: string): Boolean;

{ Is_Tar_Suffix: true for .tar / .tar.gz / .tar.bz2 / ... names }
function Is_Tar_Suffix(const F: string): Boolean;

{ Get_Compound_Ext_Last: last component of a compound suffix,
  e.g. .tar.gz -> gz }
function Get_Compound_Ext_Last(const F: string): string;

{ Archive_Main_Name: main directory inside an archive, or base name of a
  single file. Returns '' when it cannot be determined. }
function Archive_Main_Name(const F: string): string;

{ Archive_Extract: extract an archive into DstDir. Result = 0 on success. }
function Archive_Extract(const F, DstDir: string): Integer;

implementation

{ Is_Zip_File reads the first four bytes and compares them with the PK
  signature used by zip archives (local header, empty/spanning or
  multi-volume markers all count as zip). }
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

{ Is_Tar_Suffix checks the compound extension for tar-family names,
  including the short forms tgz/tbz2/tbz/txz/tzst. }
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

{ Get_Compound_Ext_Last returns the last component of a compound suffix
  (the compression layer), falling back to the plain file extension. }
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

{ Archive_Main_Name inspects the archive contents: for zip the central
  directory is read natively with TUnZipper.Examine, otherwise tar -tf is
  used. When every entry shares one top-level directory that name is the
  result; a single-file archive yields its base name; anything ambiguous
  returns ''. }
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

{ Archive_Extract dispatches on archive kind: zip is unpacked natively with
  TUnZipper, tar-family archives with tar -xf, and the remaining formats
  with their dedicated tools; single-stream formats (gz/bz2/xz/zst) are
  decompressed through sh so the output file name can be chosen. }
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

end.
