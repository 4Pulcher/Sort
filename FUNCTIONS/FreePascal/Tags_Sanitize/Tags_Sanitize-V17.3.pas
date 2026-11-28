function Tags_Sanitize(const S: string): string;
var
    I: Integer;
begin
    Result := '';
    for I := 1 to Length(S) do
        if S[I] = ' ' then
            Result := Result + '_'
        else if not (S[I] in ['/', '\\', ':', '*', '?', '"', '<', '>', '|']) then
            Result := Result + S[I];
end;
