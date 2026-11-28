function Id3v1_Field(const F, Field: string): string;
var
    FS: TFileStream;
    Buf: array[0..127] of Byte;
    Off, Len, I: Integer;
    Field_L: string;
begin
    Result := '';
    if not Id3v1_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := FS.Size - 128;
        FS.ReadBuffer(Buf, 128);
    finally
        FS.Free;
    end;
    Field_L := LowerCase(Field);
    if Field_L = 'track' then
    begin
        { track byte only valid when the comment zero-separator is there }
        if (Buf[125] = 0) and (Buf[126] <> 0) then
            Result := IntToStr(Buf[126]);
        Exit;
    end;
    if Field_L = 'genre' then
    begin
        if (Buf[127] < 255) and (Buf[127] <= 125) then
            Result := Genre_Table[Buf[127]]
        else if Buf[127] < 255 then
            Result := IntToStr(Buf[127]);
        Exit;
    end;
    if Field_L = 'title' then
    begin
        Off := 3;
        Len := 30;
    end
    else if Field_L = 'artist' then
    begin
        Off := 33;
        Len := 30;
    end
    else if Field_L = 'album' then
    begin
        Off := 63;
        Len := 30;
    end
    else if Field_L = 'year' then
    begin
        Off := 93;
        Len := 4;
    end
    else if Field_L = 'comment' then
    begin
        Off := 97;
        Len := 28;
    end
    else
        Exit;
    for I := Off to Off + Len - 1 do
        Result := Result + Chr(Buf[I]);
    Result := Trim_Tags(Result);
end;
