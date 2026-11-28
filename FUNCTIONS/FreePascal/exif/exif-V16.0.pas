{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : exif.pas                                                         }
{  Version : 1.0                                                              }
{  Desc    : EXIF toolkit - generic metadata field access via exiftool        }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh exif.pas    }
{                                                                             }
{*****************************************************************************}
unit exif;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, systools;

{ Exif_Field: one metadata field of a file via exiftool
  (e.g. Field = 'Model', 'DateTimeOriginal', 'Title', 'GPSLatitude') }
function Exif_Field(const F, Field: string): string;

{ Exif_Camera: EXIF camera as a directory tag }
function Exif_Camera(const F: string): string;

{ Exif_Date: EXIF capture date as YYYY-MM-DD }
function Exif_Date(const F: string): string;

implementation

function Exif_Field(const F, Field: string): string;
var
    Res: string;
begin
    Result := '';
    if RunTool('exiftool', ['-s3', '-' + Field, F], Res) = 0 then
        Result := Trim(Res);
end;

function Exif_Camera(const F: string): string;
begin
    Result := Exif_Field(F, 'Model');
end;

function Exif_Date(const F: string): string;
var
    D: string;
begin
    D := Exif_Field(F, 'DateTimeOriginal');
    if D = '' then
        D := Exif_Field(F, 'CreateDate');
    if Length(D) >= 10 then
        Result := Copy(D, 1, 4) + '-' + Copy(D, 6, 2) + '-' + Copy(D, 9, 2)
    else
        Result := '';
end;

end.
