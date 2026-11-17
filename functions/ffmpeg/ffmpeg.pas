{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : ffmpeg.pas                                                       }
{  Version : 1.0                                                              }
{  Desc    : Media toolkit - duration and tags via ffprobe / exiftool         }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh ffmpeg.pas  }
{                                                                             }
{*****************************************************************************}
unit ffmpeg;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, systools, exif;

{ Video_Duration: video duration in whole seconds via ffprobe }
function Video_Duration(const F: string): string;

{ Media_Title: embedded media title via exiftool }
function Media_Title(const F: string): string;

{ Media_Camera: camera model via exiftool }
function Media_Camera(const F: string): string;

implementation

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

function Media_Title(const F: string): string;
begin
    Result := Exif_Field(F, 'Title');
end;

function Media_Camera(const F: string): string;
begin
    Result := Exif_Field(F, 'Model');
end;

end.
