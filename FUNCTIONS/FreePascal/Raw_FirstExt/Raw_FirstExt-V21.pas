function Raw_FirstExt(const Exts: string): string;
var
    P: Integer;
begin
    P := Pos(',', Exts);
    if (Exts = '') or (P = 1) then
        Result := 'bin'
    else if P = 0 then
        Result := Exts
    else
        Result := Copy(Exts, 1, P - 1);
end;
