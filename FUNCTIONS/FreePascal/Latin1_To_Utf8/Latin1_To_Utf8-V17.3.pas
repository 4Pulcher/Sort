function Latin1_To_Utf8(const S: string): string;
var
    I: Integer;
    C: Byte;
begin
    Result := '';
    for I := 1 to Length(S) do
    begin
        C := Ord(S[I]);
        if C < 128 then
            Result := Result + S[I]
        else
            Result := Result + Chr($C0 or (C shr 6)) + Chr($80 or (C and $3F));
    end;
end;
