{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : hash.pas                                                         }
{  Version : 1.0                                                              }
{  Desc    : Checksum toolkit - md5 / sha1 native, sha256/sha512 external     }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh hash.pas    }
{                                                                             }
{*****************************************************************************}
unit hash;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, MD5, SHA1, systools;

{ Hash_String: hash a string with the given algorithm (md5/sha1 native) }
function Hash_String(const S, Algo: string): string;

{ Hash_File: hash a file with the given algorithm
  (md5/sha1 native; sha256/sha512 via the external sum tools, because FPC
  has no native SHA256/SHA512 unit) }
function Hash_File(const F, Algo: string): string;

implementation

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

function Hash_String(const S, Algo: string): string;
begin
    Result := '';
    if Algo = 'md5' then
        Result := MD5Print(MD5String(S))
    else if Algo = 'sha1' then
        Result := SHA1Print(SHA1String(S));
end;

function Hash_File(const F, Algo: string): string;
var
    Res: string;
begin
    Result := '';
    if Algo = 'md5' then
        Result := MD5Print(MD5File(F))
    else if Algo = 'sha1' then
        Result := SHA1Print(SHA1File(F))
    else if Algo = 'sha256' then
    begin
        if RunTool('sha256sum', [F], Res) = 0 then
            Result := First_Token(Trim(Res));
    end
    else if Algo = 'sha512' then
    begin
        if RunTool('sha512sum', [F], Res) = 0 then
            Result := First_Token(Trim(Res));
    end;
end;

end.
