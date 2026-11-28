{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : coretools.pas                                                    }
{  Version : 1.0                                                              }
{  Desc    : Core naming toolkit - sanitize / underscore / unique targets     }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh coretools.pas }
{                                                                             }
{*****************************************************************************}
unit coretools;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, filetools, hash, mime, compression, exif, imagemagick,
    ffmpeg, systools;

{ Sanitize_Name: replace filesystem-unsafe characters with underscores }
function Sanitize_Name(const S: string): string;

{ Underscore: replace spaces with underscores }
function Underscore(const S: string): string;

{ Unique_Target: append ~(N) when the target already exists.
  Destructive = true (remove/trash/shred style modes) returns the target
  unchanged, because the existing file is about to be replaced anyway. }
function Unique_Target(const T: string; Destructive: Boolean): string;

implementation

{ Sanitize_Name walks the string once and maps every character that is
  problematic on Unix and Windows file systems to an underscore. }
function Sanitize_Name(const S: string): string;
var
    I: Integer;
begin
    Result := S;
    for I := 1 to Length(Result) do
        if CharInSet(Result[I], ['/', '\', ':', '*', '?', '"', '<', '>', '|']) then
            Result[I] := '_';
end;

{ Underscore walks the string once and replaces every space with an
  underscore, so names stay single-token. }
function Underscore(const S: string): string;
var
    I: Integer;
begin
    Result := S;
    for I := 1 to Length(Result) do
        if Result[I] = ' ' then
            Result[I] := '_';
end;

{ Unique_Target checks for an existing file at T and, when found and the
  mode is non-destructive, appends ~(1), ~(2), ... before the extension
  until a free name is reached. }
function Unique_Target(const T: string; Destructive: Boolean): string;
var
    N: Integer;
    Base, Ext: string;
begin
    Result := T;
    if Destructive then
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

end.
