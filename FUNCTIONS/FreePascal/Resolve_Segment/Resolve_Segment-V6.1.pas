function Resolve_Segment(const Value, F: string; out Text: string): Integer;
var
    Mime, DT, Tmp: string;
    W, H: Integer;
    P: Integer;
begin
    Text := '';
    Result := 0;
    if Value = 'accessed' then
        Text := FormatDateTime('yyyy-mm-dd', File_Time(F, 'accessed'))
    else if Value = 'created' then
        Text := FormatDateTime('yyyy-mm-dd', File_Time(F, 'created'))
    if Value = 'extension' then
        Text := Get_File_Ext(F)
    else if Value = 'format' then
    begin
        if not Image_WxH(F, W, H) then
            Exit(1);
        Text := Media_Tier(W, H) + '-' + Media_Orient(W, H);
    end
    if Value = 'mime' then
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
    else if Value = 'modified' then
        Text := FormatDateTime('yyyy-mm-dd', File_Time(F, 'modified'))
    else if Value = 'random' then
        Text := IntToStr(Random(100000))
    else if Value = 'size' then
        Text := IntToStr(Get_File_Size(F))
    else if Value = 'year' then
        Text := FormatDateTime('yyyy', File_Time(F, 'modified'))
    else
        Result := 2;  { unknown -> treated as literal }
end;
