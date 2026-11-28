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
