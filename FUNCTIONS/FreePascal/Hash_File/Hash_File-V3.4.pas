function Hash_File(const F, Algo: string): string;
var
    Res: string;
begin
    Result := '';
    if Algo = 'md5' then
        Result := MD5Print(MD5File(F));
    else if Algo = 'sha1' then
        Result := SHA1Print(SHA1File(F));
end;
