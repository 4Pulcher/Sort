{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : mime.pas                                                         }
{  Version : 1.0                                                              }
{  Desc    : MIME toolkit - type detection, main/sub, best-match extension    }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh mime.pas    }
{                                                                             }
{*****************************************************************************}
unit mime;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, systools;

{ Detect_MIME: MIME type of a file via file(1) }
function Detect_MIME(const F: string): string;

{ MIME_Main: main part of a MIME type (before the /) }
function MIME_Main(const M: string): string;

{ MIME_Sub: sub part of a MIME type (after the /) }
function MIME_Sub(const M: string): string;

{ MIME_Table: best known extension for a MIME type
  (compact subset of the shell 687-entry table; '' when unknown) }
function MIME_Table(const M: string): string;

{ Ext_To_MIME: extension -> MIME type ('' when unknown) }
function Ext_To_MIME(const E: string): string;

{ Get_MIME_Best_Extension: best matching extension for the MIME type of a
  file, using the same chain as shell mime v2.2: exact table hit, own
  extension when it maps back to the type, main-type default for
  extensionless files, original extension as last resort }
function Get_MIME_Best_Extension(const F: string): string;

implementation

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

function MIME_Table(const M: string): string;
begin
    if M = 'text/plain' then Result := 'txt'
    else if M = 'text/x-shellscript' then Result := 'sh'
    else if M = 'text/html' then Result := 'html'
    else if M = 'text/csv' then Result := 'csv'
    else if M = 'text/markdown' then Result := 'md'
    else if M = 'application/pdf' then Result := 'pdf'
    else if M = 'application/zip' then Result := 'zip'
    else if M = 'application/gzip' then Result := 'gz'
    else if M = 'application/x-gzip' then Result := 'gz'
    else if M = 'application/x-bzip2' then Result := 'bz2'
    else if M = 'application/x-xz' then Result := 'xz'
    else if M = 'application/zstd' then Result := 'zst'
    else if M = 'application/x-7z-compressed' then Result := '7z'
    else if M = 'application/x-rar' then Result := 'rar'
    else if M = 'application/x-rar-compressed' then Result := 'rar'
    else if M = 'application/x-tar' then Result := 'tar'
    else if M = 'application/json' then Result := 'json'
    else if M = 'application/xml' then Result := 'xml'
    else if M = 'application/x-yaml' then Result := 'yaml'
    else if M = 'image/jpeg' then Result := 'jpg'
    else if M = 'image/png' then Result := 'png'
    else if M = 'image/gif' then Result := 'gif'
    else if M = 'image/webp' then Result := 'webp'
    else if M = 'image/svg+xml' then Result := 'svg'
    else if M = 'image/tiff' then Result := 'tif'
    else if M = 'image/bmp' then Result := 'bmp'
    else if M = 'image/x-icon' then Result := 'ico'
    else if M = 'audio/mpeg' then Result := 'mp3'
    else if M = 'audio/ogg' then Result := 'ogg'
    else if M = 'audio/wav' then Result := 'wav'
    else if M = 'audio/x-wav' then Result := 'wav'
    else if M = 'audio/flac' then Result := 'flac'
    else if M = 'audio/mp4' then Result := 'm4a'
    else if M = 'video/mp4' then Result := 'mp4'
    else if M = 'video/mpeg' then Result := 'mpeg'
    else if M = 'video/webm' then Result := 'webm'
    else if M = 'video/x-matroska' then Result := 'mkv'
    else if M = 'video/quicktime' then Result := 'mov'
    else if M = 'video/x-msvideo' then Result := 'avi'
    else if M = 'application/octet-stream' then Result := 'bin'
    else if M = 'application/x-executable' then Result := 'bin'
    else if M = 'application/x-sharedlib' then Result := 'so'
    else if M = 'application/x-object' then Result := 'o'
    else if M = 'application/sql' then Result := 'sql'
    else if M = 'application/x-sqlite3' then Result := 'sqlite'
    else if M = 'application/epub+zip' then Result := 'epub'
    else if M = 'application/vnd.debian.binary-package' then Result := 'deb'
    else if M = 'application/x-rpm' then Result := 'rpm'
    else if M = 'application/msword' then Result := 'doc'
    else if M = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' then Result := 'docx'
    else if M = 'application/vnd.ms-excel' then Result := 'xls'
    else if M = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' then Result := 'xlsx'
    else if M = 'application/vnd.ms-powerpoint' then Result := 'ppt'
    else if M = 'application/vnd.openxmlformats-officedocument.presentationml.presentation' then Result := 'pptx'
    else if M = 'application/font-woff' then Result := 'woff'
    else if M = 'application/x-font-ttf' then Result := 'ttf'
    else if M = 'application/x-font-otf' then Result := 'otf'
    else
        Result := '';
end;

function Ext_To_MIME(const E: string): string;
begin
    if E = 'txt' then Result := 'text/plain'
    else if E = 'sh' then Result := 'text/x-shellscript'
    else if E = 'html' then Result := 'text/html'
    else if E = 'csv' then Result := 'text/csv'
    else if E = 'md' then Result := 'text/markdown'
    else if E = 'pdf' then Result := 'application/pdf'
    else if E = 'zip' then Result := 'application/zip'
    else if E = 'gz' then Result := 'application/gzip'
    else if E = 'bz2' then Result := 'application/x-bzip2'
    else if E = 'xz' then Result := 'application/x-xz'
    else if E = 'zst' then Result := 'application/zstd'
    else if E = '7z' then Result := 'application/x-7z-compressed'
    else if E = 'rar' then Result := 'application/x-rar'
    else if E = 'tar' then Result := 'application/x-tar'
    else if E = 'jpg' then Result := 'image/jpeg'
    else if E = 'jpeg' then Result := 'image/jpeg'
    else if E = 'png' then Result := 'image/png'
    else if E = 'gif' then Result := 'image/gif'
    else if E = 'webp' then Result := 'image/webp'
    else if E = 'svg' then Result := 'image/svg+xml'
    else if E = 'mp3' then Result := 'audio/mpeg'
    else if E = 'ogg' then Result := 'audio/ogg'
    else if E = 'wav' then Result := 'audio/x-wav'
    else if E = 'flac' then Result := 'audio/flac'
    else if E = 'mp4' then Result := 'video/mp4'
    else if E = 'mkv' then Result := 'video/x-matroska'
    else if E = 'webm' then Result := 'video/webm'
    else if E = 'mov' then Result := 'video/quicktime'
    else if E = 'avi' then Result := 'video/x-msvideo'
    else if E = 'json' then Result := 'application/json'
    else if E = 'xml' then Result := 'application/xml'
    else
        Result := '';
end;

function Get_MIME_Best_Extension(const F: string): string;
var
    Mime, OwnExt, Base: string;
    Dot: Integer;
begin
    Result := '';
    Mime := Detect_MIME(F);
    if Mime = '' then
        Exit;
    { 1: exact table hit }
    Result := MIME_Table(Mime);
    if Result <> '' then
        Exit;
    Base := ExtractFileName(F);
    Dot := LastDelimiter('.', Base);
    { 2: keep the file's own extension when it maps back to the type }
    if Dot > 1 then
    begin
        OwnExt := LowerCase(Copy(Base, Dot + 1, MaxInt));
        if Ext_To_MIME(OwnExt) = Mime then
        begin
            Result := OwnExt;
            Exit;
        end;
    end;
    { 3: main-type default for extensionless files }
    if Dot <= 1 then
    begin
        if MIME_Main(Mime) = 'text' then Result := 'txt'
        else if MIME_Main(Mime) = 'image' then Result := 'img'
        else if MIME_Main(Mime) = 'audio' then Result := 'mp3'
        else if MIME_Main(Mime) = 'video' then Result := 'mp4'
        else if MIME_Main(Mime) = 'application' then Result := 'bin';
    end;
    { 4: original extension as last resort }
    if (Result = '') and (Dot > 1) then
        Result := LowerCase(Copy(Base, Dot + 1, MaxInt));
end;

end.
