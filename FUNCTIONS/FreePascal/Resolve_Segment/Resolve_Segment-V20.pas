function Resolve_Segment(const Value, F: string; out Text: string): Integer;
var
    Mime, DT, Tmp: string;
    W, H: Integer;
    P: Integer;
begin
    Text := '';
    Result := 0;
    if Value = 'extension' then
    begin
        if Get_Compound_Ext(F, Tmp) then
            Text := Tmp
        else
            Text := Get_File_Ext(F);
    end
    else if Value = 'mime' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := Mime;
    end
    else if Value = 'mime-main' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := UpCase(MIME_Main(Mime));
    end
    else if Value = 'mime-sub' then
    begin
        Mime := Detect_MIME(F);
        if Mime = '' then
            Exit(1);
        Text := MIME_Sub(Mime);
    end
    else if Value = 'mime-ext' then
    begin
        Text := Get_MIME_Best_Extension(F);
        if Text = '' then
            Exit(1);
    end
    else if Value = 'year' then
        Text := FormatDateTime('yyyy', File_Time(F, 'modified'))
    else if (Value = 'created') or (Value = 'modified') or (Value = 'accessed') then
    begin
        DT := File_Time(F, Value);
        Text := FormatDateTime('yyyy-mm-dd', DT);
    end
    else if (Value = 'md5') or (Value = 'sha1') or (Value = 'sha256')
            or (Value = 'sha512') then
    begin
        Text := Hash_File(F, Value);
        if Text = '' then
            Exit(1);
    end
    else if Value = 'sha' then
    begin
        Text := Hash_File(F, 'sha256');
        if Text = '' then
            Exit(1);
    end
    else if Value = 'random' then
        Text := IntToStr(Random(100000))
    else if Value = 'size' then
        Text := IntToStr(Get_File_Size(F))
    else if Value = 'format' then
    begin
        if not Image_WxH(F, W, H) then
            Exit(1);
        Text := Media_Tier(W, H) + '-' + Media_Orient(W, H);
    end
    else if Value = 'duration' then
    begin
        Text := Video_Duration(F);
        if Text = '' then
            Exit(1);
    end
    else if (Value = 'id3') or (Value = 'audio') then
    begin
        Text := Get_Audio_Tags_Dir(F);
        if Text = '' then
            Exit(1);
    end
    else if Pos('id3-', Value) = 1 then
    begin
        Tmp := Id3_Field(F, Copy(Value, 5, MaxInt));
        if Tmp = '' then
            Exit(1);
        Text := Tags_Sanitize(Tmp);
    end
    else if Value = 'camera' then
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
    else if (Value = 'title') or (Value = 'long') or (Value = 'short') then
    begin
        Text := Exif_Field(F, 'Title');
        if Text = '' then
            Text := Get_Base_Name(F);
        Text := Underscore(Text);
    end
    else if Value = 'compressed' then
    begin
        Text := Archive_Main_Name(F);
        if Text = '' then
            Text := Get_Base_Name(F);
    end
    else if (Value = 'folder') or (Value = 'folder_name') then
        Text := ExtractFileName(ExtractFileDir(ExpandFileName(F)))
    else
        Result := 2;  { unknown -> treated as literal }
end;
