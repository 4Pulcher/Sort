function Hash_File(const F: string): string;
var
    Res: string;
begin
    Result := '';
    if RunTool('sha256sum', ['-b', F], Res) = 0 then
        Result := First_Token(Trim(Res));
end;
