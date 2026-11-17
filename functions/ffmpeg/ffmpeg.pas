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
    SysUtils, Classes, systools, exif;

{ Video_Duration: video duration in whole seconds via ffprobe }
function Video_Duration(const F: string): string;

{ Duration_Tag_From_Seconds: HH-MM-SS tag from a seconds value - shared core
  for the duration segments }
function Duration_Tag_From_Seconds(Seconds: string): string;

{ Video_Duration_Tag: duration of a video as an HH-MM-SS tag, empty when
  unusable }
function Video_Duration_Tag(const F: string): string;

{ Get_Media_Info: width, height and duration in ONE ffprobe call - returns
  "<WxH>|<HH-MM-SS>", e.g. 1920x1080|00-02-03; 0x0|unknown on failure }
function Get_Media_Info(const F: string): string;

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

{ Duration_Tag_From_Seconds: HH-MM-SS tag from a seconds value - shared core
  for the duration segments }
function Duration_Tag_From_Seconds(Seconds: string): string;
var
    P: Integer;
    V, H, M, S: Int64;
begin
    P := Pos('.', Seconds);
    if P > 0 then
        Seconds := Copy(Seconds, 1, P - 1);
    if Seconds = '' then
        Seconds := '0';
    V := StrToIntDef(Seconds, 0);
    H := V div 3600;
    M := (V mod 3600) div 60;
    S := V mod 60;
    Result := Format('%.2d-%.2d-%.2d', [H, M, S]);
end;

{ Video_Duration_Tag: duration of a video as an HH-MM-SS tag, empty when
  unusable }
function Video_Duration_Tag(const F: string): string;
begin
    Result := Duration_Tag_From_Seconds(Video_Duration(F));
end;

{ Get_Token: the Nth whitespace-separated token of S, empty when absent }
function Get_Token(const S: string; N: Integer): string;
var
    Parts: TStringList;
begin
    Result := '';
    Parts := TStringList.Create;
    try
        Parts.Delimiter := ' ';
        Parts.StrictDelimiter := True;
        Parts.DelimitedText := S;
        if N <= Parts.Count then
            Result := Parts[N - 1];
    finally
        Parts.Free;
    end;
end;

{ Is_Number: true when S is a non-empty run of digits }
function Is_Number(const S: string): Boolean;
var
    I: Integer;
begin
    Result := (S <> '');
    for I := 1 to Length(S) do
        if not (S[I] in ['0'..'9']) then
            Exit(False);
end;

{ Get_Media_Info: width, height and duration in ONE ffprobe call - returns
  "<WxH>|<HH-MM-SS>", e.g. 1920x1080|00-02-03; 0x0|unknown on failure }
function Get_Media_Info(const F: string): string;
var
    Res, W, H, Dur: string;
begin
    if RunTool('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
                           '-show_entries', 'stream=width,height:format=duration',
                           '-of', 'default=noprint_wrappers=1:nokey=1', F],
               Res) <> 0 then
        Exit('0x0|unknown');

    { Lines: width, height, duration - flatten and read them back }
    Res := StringReplace(Trim(Res), #10, ' ', [rfReplaceAll]);
    W := Get_Token(Res, 1);
    H := Get_Token(Res, 2);
    Dur := Get_Token(Res, 3);

    if Is_Number(W) and Is_Number(H) then
        Result := W + 'x' + H
    else
        Result := '0x0';

    if Is_Number(Dur) then
        Result := Result + '|' + Duration_Tag_From_Seconds(Dur)
    else
        Result := Result + '|unknown';
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
