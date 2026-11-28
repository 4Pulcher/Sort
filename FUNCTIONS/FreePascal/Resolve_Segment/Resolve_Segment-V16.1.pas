function Resolve_Segment(const Value, F: string; out Text: string): Integer;
var
    Mime, DT, Tmp: string;
    W, H: Integer;
    P: Integer;
begin
    Text := '';
    Result := 0;
    if Value = 'camera' then
    begin
        Text := Underscore(Exif_Field(F, 'Model'));
        if Text = '' then
            Exit(1);
    end
    else if Value = 'exifdate' then
    begin
        Tmp := Exif_Field(F, 'DateTimeOriginal');
        P := Pos(' ', Tmp);
        if P = 0 then
            Exit(1);
        Tmp := Copy(Tmp, 1, P - 1);
        for P := 1 to Length(Tmp) do
            if Tmp[P] = ':' then
                Tmp[P] := '-';
        Text := Tmp;
    end
    if Value = 'extension' then
        Text := Get_File_Ext(F)
    if Value = 'mime' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := Mime;
    end
    else if Value = 'mime-sub' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := MIME_Sub(Mime);
    end
    else if Value = 'random' then
        Text := IntToStr(Random(100000))
    else if (Value = 'title') or (Value = 'long') or (Value = 'short') then
    begin
        Text := Exif_Field(F, 'Title');
        if Text = '' then
            Text := Get_Base_Name(F);
        Text := Underscore(Text);
    end
    else
        Result := 2;  { unknown -> treated as literal }
end;
