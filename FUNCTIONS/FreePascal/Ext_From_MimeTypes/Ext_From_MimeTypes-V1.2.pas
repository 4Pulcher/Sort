function Ext_From_MimeTypes(const Mime: string): string;
var
    I: Integer;
    Line, Key: string;
begin
    Result := '';
    if MimeTypes = nil then
        Exit;
    for I := 0 to MimeTypes.Count - 1 do
    begin
        Line := Trim(MimeTypes[I]);
        if (Line = '') or (Line[1] = '#') then
            Continue;
        Key := Copy(Line, 1, Pos(' ', Line + ' ') - 1);
        if Key = Mime then
        begin
            Line := Trim(Copy(Line, Length(Key) + 1, MaxInt));
            if Pos(' ', Line) > 0 then
                Line := Copy(Line, 1, Pos(' ', Line) - 1);
            Result := Line;
            Exit;
        end;
    end;
end;
