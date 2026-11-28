function Get_MIME_Best_Extension(const F: string): string;
var
    Mime, OwnExt, Base: string;
    Dot: Integer;
begin
    Result := '';
    Mime := Detect_MIME(F);
    if Mime = '' then
        Exit;
    Result := MIME_Table(Mime);
    if Result <> '' then
        Exit;
    Base := ExtractFileName(F);
    Dot := LastDelimiter('.', Base);
    if Dot > 1 then
    begin
        OwnExt := LowerCase(Copy(Base, Dot + 1, MaxInt));
        if Ext_To_MIME(OwnExt) = Mime then
            Result := OwnExt;
    end;
    if (Result = '') and (Dot > 1) then
        Result := LowerCase(Copy(Base, Dot + 1, MaxInt));
end;
